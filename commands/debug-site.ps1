<#
.SYNOPSIS
    Gestiona el modo debug de WordPress en un sitio.
.DESCRIPTION
    Permite habilitar, deshabilitar o ver el estado del modo debug de WordPress.
    Modifica wp-config.php para agregar/quitar las constantes de debug.
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER Enable
    Habilita el modo debug (WP_DEBUG, WP_DEBUG_LOG, WP_DEBUG_DISPLAY=false)
.PARAMETER Disable
    Deshabilita el modo debug
.PARAMETER Status
    Muestra el estado actual del modo debug (default si no se especifica nada)
.EXAMPLE
    .\debug-site.ps1 -SiteName "padel" -Enable
.EXAMPLE
    .\debug-site.ps1 -SiteName "padel" -Disable
.EXAMPLE
    .\debug-site.ps1 -SiteName "padel" -Status
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [switch]$Enable,
    
    [switch]$Disable,
    
    [switch]$Status
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

<#
Validacion: Verificar que el sitio existe y tiene UUID configurado
#>
try {
    $siteConfig = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "DEBUG" -Message "Gestionando debug de: $SiteName" -Source "debug-site"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$containerId = Get-WordPressContainerId -Uuid $siteConfig.stackUuid
if (-not $containerId) {
    Write-Host "No se encontro contenedor WordPress para: $SiteName" -ForegroundColor Red
    exit 1
}

$vps = Get-VpsConfig
$sshTarget = "$($vps.user)@$($vps.ip)"
$wpConfigPath = "/var/www/html/wp-config.php"

<#
Funcion auxiliar: Verificar si debug esta habilitado
#>
function Get-DebugStatus {
    $checkCmd = "docker exec $containerId grep -c 'GLORY_DEBUG_ENABLED' $wpConfigPath 2>/dev/null || echo '0'"
    $result = ssh $sshTarget $checkCmd 2>&1
    return ($result.Trim() -ne "0")
}

<#
Si no se especifica ninguna accion, mostrar status
#>
if (-not $Enable -and -not $Disable) {
    $Status = $true
}

<#
Mostrar estado actual
#>
if ($Status -and -not $Enable -and -not $Disable) {
    Write-Host ""
    Write-Host "Estado Debug - $SiteName" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    
    $isEnabled = Get-DebugStatus
    
    if ($isEnabled) {
        Write-Host "  Debug: " -NoNewline
        Write-Host "HABILITADO" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Para ver logs:" -ForegroundColor DarkGray
        Write-Host "  .\manager.ps1 logs -SiteName $SiteName -WpDebug" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Para deshabilitar:" -ForegroundColor DarkGray
        Write-Host "  .\manager.ps1 debug -SiteName $SiteName -Disable" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  Debug: " -NoNewline
        Write-Host "DESHABILITADO" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Para habilitar:" -ForegroundColor DarkGray
        Write-Host "  .\manager.ps1 debug -SiteName $SiteName -Enable" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    exit 0
}

<#
Habilitar debug
#>
if ($Enable) {
    Write-Host ""
    Write-Host "Habilitando modo debug para: $SiteName" -ForegroundColor Yellow
    Write-Host ""
    
    $isEnabled = Get-DebugStatus
    if ($isEnabled) {
        Write-Host "El modo debug ya esta habilitado." -ForegroundColor Green
        exit 0
    }
    
    # Script PHP para agregar las constantes de debug de forma segura
    $phpScript = @'
<?php
$configPath = '/var/www/html/wp-config.php';
$content = file_get_contents($configPath);

// Marcador para identificar nuestras lineas de debug
$debugBlock = <<<'EOD'

/* GLORY_DEBUG_ENABLED - Inicio */
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
@ini_set( 'display_errors', 0 );
/* GLORY_DEBUG_ENABLED - Fin */

EOD;

// Insertar despues de <?php
$content = preg_replace('/^<\?php/', "<?php" . $debugBlock, $content, 1);

// Backup
copy($configPath, $configPath . '.bak');

// Guardar
file_put_contents($configPath, $content);
echo "DEBUG_ENABLED";
'@

    # Ejecutar el script PHP
    $phpScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($phpScript))
    $execCmd = "docker exec $containerId bash -c 'echo $phpScriptBase64 | base64 -d | php'"
    
    Write-Host "Modificando wp-config.php..." -ForegroundColor DarkGray
    $result = ssh $sshTarget $execCmd 2>&1
    
    if ($result -match "DEBUG_ENABLED") {
        Write-Host ""
        Write-Host "Modo debug HABILITADO" -ForegroundColor Green
        Write-Host ""
        Write-Host "Ahora puedes ver los logs con:" -ForegroundColor Cyan
        Write-Host "  .\manager.ps1 logs -SiteName $SiteName -WpDebug" -ForegroundColor White
        Write-Host ""
        Write-Host "Para filtrar por patron:" -ForegroundColor Cyan
        Write-Host "  .\manager.ps1 logs -SiteName $SiteName -WpDebug -Filter 'AmazonAJAX'" -ForegroundColor White
    }
    else {
        Write-Host "Error al habilitar debug: $result" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    exit 0
}

<#
Deshabilitar debug
#>
if ($Disable) {
    Write-Host ""
    Write-Host "Deshabilitando modo debug para: $SiteName" -ForegroundColor Yellow
    Write-Host ""
    
    $isEnabled = Get-DebugStatus
    if (-not $isEnabled) {
        Write-Host "El modo debug ya esta deshabilitado." -ForegroundColor Green
        exit 0
    }
    
    # Script PHP para quitar las constantes de debug
    $phpScript = @'
<?php
$configPath = '/var/www/html/wp-config.php';
$content = file_get_contents($configPath);

// Quitar el bloque de debug
$pattern = '/\n\/\* GLORY_DEBUG_ENABLED - Inicio \*\/.*?\/\* GLORY_DEBUG_ENABLED - Fin \*\/\n/s';
$content = preg_replace($pattern, '', $content);

// Guardar
file_put_contents($configPath, $content);
echo "DEBUG_DISABLED";
'@

    # Ejecutar el script PHP
    $phpScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($phpScript))
    $execCmd = "docker exec $containerId bash -c 'echo $phpScriptBase64 | base64 -d | php'"
    
    Write-Host "Modificando wp-config.php..." -ForegroundColor DarkGray
    $result = ssh $sshTarget $execCmd 2>&1
    
    if ($result -match "DEBUG_DISABLED") {
        Write-Host ""
        Write-Host "Modo debug DESHABILITADO" -ForegroundColor Green
        Write-Host ""
        Write-Host "Para volver a habilitarlo:" -ForegroundColor Cyan
        Write-Host "  .\manager.ps1 debug -SiteName $SiteName -Enable" -ForegroundColor White
    }
    else {
        Write-Host "Error al deshabilitar debug: $result" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    exit 0
}
