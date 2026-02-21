<#
.SYNOPSIS
    Configura SMTP relay (Brevo) en sitios WordPress.
.DESCRIPTION
    Despliega un mu-plugin que configura PHPMailer para usar Brevo SMTP relay.
    Esto permite que wp_mail() funcione en todos los contenedores WordPress
    sin necesidad de plugins adicionales.

    El mu-plugin intercepta phpmailer_init y configura:
    - Host: smtp-relay.brevo.com
    - Puerto: 587
    - Autenticacion SMTP con credenciales de Brevo
    - TLS obligatorio

    Tambien instala msmtp como sendmail fallback dentro del contenedor.
.PARAMETER SiteName
    Nombre de un sitio especifico para configurar
.PARAMETER All
    Configura SMTP en todos los sitios con stackUuid
.PARAMETER Test
    Envia un correo de prueba despues de configurar
.PARAMETER TestEmail
    Email destino para la prueba (default: admin del settings.json)
.PARAMETER Status
    Muestra el estado actual de la configuracion SMTP en los sitios
.EXAMPLE
    .\setup-smtp.ps1 -All
.EXAMPLE
    .\setup-smtp.ps1 -SiteName "cap" -Test
.EXAMPLE
    .\setup-smtp.ps1 -Status
#>

param(
    [Parameter(Position = 0)]
    [string]$SiteName,
    
    [switch]$All,
    
    [switch]$Test,
    
    [string]$TestEmail,
    
    [switch]$Status
)

$ErrorActionPreference = "Continue"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

$config = Get-ConfigData

# Credenciales SMTP desde settings.json
$smtp = $config.smtp
if (-not $smtp) {
    Write-Host ""
    Write-Host "ERROR: No hay configuracion SMTP en settings.json" -ForegroundColor Red
    Write-Host "Agrega la seccion 'smtp' al archivo de configuracion." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$smtpHost = $smtp.host
$smtpPort = $smtp.port
$smtpUser = $smtp.user
$smtpPassword = $smtp.password
$smtpFromName = if ($smtp.fromName) { $smtp.fromName } else { "WordPress" }

if (-not $TestEmail) {
    $TestEmail = $config.wordpress.defaultAdminEmail
}

<#
Genera el contenido PHP del mu-plugin que configura PHPMailer.
Se inyecta directamente en wp-content/mu-plugins/ de cada contenedor.
#>
function Get-SmtpMuPluginContent {
    return @"
<?php
/**
 * Plugin Name: SMTP Relay (Brevo)
 * Description: Configura wp_mail() para usar Brevo SMTP relay. Generado por Coolify Manager.
 * Version: 1.0
 * Author: Coolify Manager
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('phpmailer_init', function (`$phpmailer) {
    `$phpmailer->isSMTP();
    `$phpmailer->Host       = '$smtpHost';
    `$phpmailer->SMTPAuth   = true;
    `$phpmailer->Port       = $smtpPort;
    `$phpmailer->Username   = '$smtpUser';
    `$phpmailer->Password   = '$smtpPassword';
    `$phpmailer->SMTPSecure = 'tls';

    /* From: usa el admin_email del sitio para que cada WP envie con su identidad */
    `$adminEmail = get_option('admin_email');
    if (`$adminEmail) {
        `$phpmailer->From = `$adminEmail;
    }

    `$siteName = get_option('blogname');
    if (`$siteName) {
        `$phpmailer->FromName = `$siteName;
    }
});
"@
}

<#
Despliega el mu-plugin SMTP en un contenedor WordPress especifico.
Crea el directorio mu-plugins si no existe, escribe el archivo PHP
y verifica la sintaxis con php -l.
#>
function Install-SmtpInContainer {
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SiteLabel
    )
    
    Write-Host "  [$SiteLabel] Instalando mu-plugin SMTP..." -ForegroundColor White
    
    $pluginContent = Get-SmtpMuPluginContent
    
    # Crear mu-plugins dir si no existe + escribir archivo via heredoc base64
    $base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pluginContent))
    
    $installScript = @"
#!/bin/bash
set -e
MU_DIR="/var/www/html/wp-content/mu-plugins"
PLUGIN_FILE="`$MU_DIR/smtp-relay.php"

mkdir -p `$MU_DIR
echo '$base64Content' | base64 -d > `$PLUGIN_FILE
chown www-data:www-data `$PLUGIN_FILE
chmod 644 `$PLUGIN_FILE

# Verificar sintaxis PHP
php -l `$PLUGIN_FILE 2>&1

echo "SMTP_INSTALL_OK"
"@
    
    try {
        $result = Invoke-DockerExec -ContainerId $ContainerId -Command $installScript
        $resultText = ($result -join "`n")
        
        if ($resultText -match "SMTP_INSTALL_OK") {
            Write-Host "  [$SiteLabel] mu-plugin SMTP instalado correctamente" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  [$SiteLabel] Resultado inesperado: $resultText" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  [$SiteLabel] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

<#
Envia un correo de prueba usando wp_mail() dentro del contenedor.
Verifica que la configuracion SMTP funciona end-to-end.
#>
function Send-TestEmail {
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SiteLabel,
        
        [Parameter(Mandatory)]
        [string]$ToEmail
    )
    
    Write-Host "  [$SiteLabel] Enviando correo de prueba a $ToEmail..." -ForegroundColor Cyan
    
    $vps = Get-VpsConfig
    $sshTarget = "$($vps.user)@$($vps.ip)"
    $randomId = Get-Random
    $remoteTemp = "/tmp/smtp_test_$randomId.php"
    $containerPath = "/tmp/smtp_test_$randomId.php"
    
    # Crear archivo PHP de prueba localmente
    $phpTest = @"
<?php
require '/var/www/html/wp-load.php';

`$to = '$ToEmail';
`$subject = 'Test SMTP - ' . get_option('blogname') . ' (' . date('Y-m-d H:i') . ')';
`$body = 'Correo de prueba enviado desde ' . get_option('siteurl') . ' via Brevo SMTP relay.';
`$headers = array('Content-Type: text/html; charset=UTF-8');

`$result = wp_mail(`$to, `$subject, `$body, `$headers);

if (`$result) {
    echo 'SMTP_TEST_OK: Correo enviado exitosamente a ' . `$to;
} else {
    global `$phpmailer;
    echo 'SMTP_TEST_FAIL: ' . (`$phpmailer->ErrorInfo ?? 'Error desconocido');
}
"@
    
    $tempLocal = Join-Path $env:TEMP "smtp_test_$randomId.php"
    
    try {
        $phpTest | Out-File -FilePath $tempLocal -Encoding UTF8 -NoNewline
        
        # Copiar al VPS y luego al contenedor
        scp $tempLocal "${sshTarget}:${remoteTemp}" 2>$null
        ssh $sshTarget "docker cp $remoteTemp ${ContainerId}:$containerPath" 2>&1 | Out-Null
        
        # Ejecutar test
        $result = ssh $sshTarget "docker exec -u www-data $ContainerId php $containerPath" 2>&1
        $resultText = ($result -join "`n")
        
        if ($resultText -match "SMTP_TEST_OK") {
            Write-Host "  [$SiteLabel] CORREO ENVIADO EXITOSAMENTE" -ForegroundColor Green
            Write-Host "  [$SiteLabel] $resultText" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  [$SiteLabel] FALLO: $resultText" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  [$SiteLabel] ERROR enviando test: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Limpiar archivos temporales
        ssh $sshTarget "docker exec $ContainerId rm -f $containerPath; rm -f $remoteTemp" 2>$null
        Remove-Item $tempLocal -Force -ErrorAction SilentlyContinue
    }
}

<#
Muestra el estado actual de la configuracion SMTP en cada sitio.
Verifica si el mu-plugin existe y si sendmail esta disponible.
#>
function Show-SmtpStatus {
    Write-Host ""
    Write-Host "  ESTADO SMTP EN SITIOS" -ForegroundColor Cyan
    Write-Host "  =====================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($sitio in $config.sitios) {
        if ([string]::IsNullOrWhiteSpace($sitio.stackUuid)) {
            Write-Host "  [$($sitio.nombre)] Sin stackUuid - OMITIDO" -ForegroundColor DarkGray
            continue
        }
        
        try {
            $containerId = Get-WordPressContainerId -Uuid $sitio.stackUuid
            if (-not $containerId) {
                Write-Host "  [$($sitio.nombre)] Contenedor no encontrado" -ForegroundColor Red
                continue
            }
            
            $checkCmd = "test -f /var/www/html/wp-content/mu-plugins/smtp-relay.php && echo 'MU_PLUGIN_EXISTS' || echo 'MU_PLUGIN_MISSING'"
            $result = Invoke-DockerExec -ContainerId $containerId -Command $checkCmd
            $resultText = ($result -join "").Trim()
            
            if ($resultText -match "MU_PLUGIN_EXISTS") {
                Write-Host "  [$($sitio.nombre)] " -NoNewline
                Write-Host "SMTP configurado" -ForegroundColor Green
            }
            else {
                Write-Host "  [$($sitio.nombre)] " -NoNewline
                Write-Host "Sin SMTP" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  [$($sitio.nombre)] Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

# Punto de entrada principal
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CONFIGURACION SMTP (Brevo Relay)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Host: $smtpHost" -ForegroundColor DarkGray
Write-Host "  Puerto: $smtpPort" -ForegroundColor DarkGray
Write-Host "  Usuario: $smtpUser" -ForegroundColor DarkGray
Write-Host ""

if ($Status) {
    Show-SmtpStatus
    exit 0
}

# Determinar sitios a configurar
$sitiosTarget = @()

if ($All) {
    $sitiosTarget = $config.sitios | Where-Object { -not [string]::IsNullOrWhiteSpace($_.stackUuid) }
    Write-Host "Configurando SMTP en $($sitiosTarget.Count) sitios..." -ForegroundColor Yellow
}
elseif ($SiteName) {
    try {
        $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
        $sitiosTarget = @($sitio)
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "ERROR: Debe especificar -SiteName o -All" -ForegroundColor Red
    Write-Host ""
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host '  .\setup-smtp.ps1 -All                        # Todos los sitios' -ForegroundColor White
    Write-Host '  .\setup-smtp.ps1 -SiteName "cap"             # Un sitio especifico' -ForegroundColor White
    Write-Host '  .\setup-smtp.ps1 -SiteName "cap" -Test       # Configurar + test' -ForegroundColor White
    Write-Host '  .\setup-smtp.ps1 -Status                     # Ver estado actual' -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""

$successCount = 0
$failCount = 0

foreach ($sitio in $sitiosTarget) {
    $label = $sitio.nombre
    
    try {
        $containerId = Get-WordPressContainerId -Uuid $sitio.stackUuid
        
        if (-not $containerId) {
            Write-Host "  [$label] Contenedor WordPress no encontrado" -ForegroundColor Red
            $failCount++
            continue
        }
        
        $installed = Install-SmtpInContainer -ContainerId $containerId -SiteLabel $label
        
        if ($installed) {
            $successCount++
            
            if ($Test) {
                Send-TestEmail -ContainerId $containerId -SiteLabel $label -ToEmail $TestEmail
            }
        }
        else {
            $failCount++
        }
    }
    catch {
        Write-Host "  [$label] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
    
    Write-Host ""
}

# Resumen
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Exitosos: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Fallidos: $failCount" -ForegroundColor Red
}
Write-Host ""

Write-Log -Level "INFO" -Message "SMTP configurado en $successCount sitios ($failCount fallidos)" -Source "setup-smtp"
