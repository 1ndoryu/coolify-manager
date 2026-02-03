<#
.SYNOPSIS
    Ejecuta un comando arbitrario en un contenedor WordPress.
.DESCRIPTION
    Permite ejecutar comandos bash o PHP directamente en el contenedor
    WordPress de un sitio especifico.
    
    IMPORTANTE: El comando bash debe ir entre comillas para evitar que 
    PowerShell interprete los guiones como parametros.
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER Command
    Comando bash a ejecutar. DEBE ir entre comillas simples o dobles.
    Ejemplo: -Command "ls -la /var/www/html"
.PARAMETER PhpCode
    Codigo PHP a ejecutar (alternativa a Command)
.PARAMETER Target
    Contenedor objetivo: wordpress o mariadb (default: wordpress)
.PARAMETER RawCommand
    Captura argumentos adicionales despues del parametro Target para
    comandos que no se pasaron con -Command
.EXAMPLE
    .\exec-command.ps1 -SiteName "padel" -Command "ls -la /var/www/html"
.EXAMPLE
    .\exec-command.ps1 -SiteName "nakomi" -PhpCode "echo get_option('siteurl');"
.EXAMPLE
    .\exec-command.ps1 -SiteName "cap" -Command "cat /var/www/html/wp-config.php | head -20"
#>

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$SiteName,
    
    [Parameter(ParameterSetName = "Bash", Position = 1)]
    [string]$Command,
    
    [Parameter(ParameterSetName = "PHP")]
    [string]$PhpCode,
    
    [ValidateSet("wordpress", "mariadb")]
    [string]$Target = "wordpress",
    
    # Captura argumentos extra que no fueron parseados correctamente
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

<#
Si hay argumentos raw capturados, combinarlos con Command.
Esto corrige el bug donde PowerShell interpreta "-la" en "ls -la" como parametro.
#>
if ($RawArgs -and $RawArgs.Count -gt 0) {
    if ($Command) {
        # Si ya hay un comando, agregar los args extra
        $Command = "$Command $($RawArgs -join ' ')"
    }
    else {
        # Si no hay comando, los RawArgs son el comando completo
        $Command = $RawArgs -join ' '
    }
    Write-Host "Comando reconstruido: $Command" -ForegroundColor DarkGray
}

# Validar que tenemos algo que ejecutar
if (-not $Command -and -not $PhpCode) {
    Write-Host ""
    Write-Host "ERROR: Debe proporcionar -Command o -PhpCode" -ForegroundColor Red
    Write-Host ""
    Write-Host "Uso correcto:" -ForegroundColor Yellow
    Write-Host '  .\exec-command.ps1 -SiteName "cap" -Command "ls -la /var/www/html"' -ForegroundColor White
    Write-Host '  .\exec-command.ps1 -SiteName "cap" -PhpCode "echo get_option(''siteurl'');"' -ForegroundColor White
    Write-Host ""
    exit 1
}

<#
Validacion: Verificar que el sitio existe y tiene UUID configurado
#>
try {
    $siteConfig = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Ejecutando comando en sitio: $SiteName" -Source "exec-command"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Usar UUID si esta disponible para busqueda mas confiable
$stackUuid = $siteConfig.stackUuid
$stackName = "$SiteName-stack"

if ($Target -eq "wordpress") {
    if ($stackUuid) {
        $containerId = Get-WordPressContainerId -Uuid $stackUuid
    }
    else {
        $containerId = Get-WordPressContainerId -StackName $stackName
    }
}
else {
    $containerId = Get-MariaDbContainerId -StackName $stackName
}

if (-not $containerId) {
    Write-Log -Level "ERROR" -Message "Contenedor $Target no encontrado para: $SiteName" -Source "exec-command"
    Write-Host "No se encontro contenedor $Target para: $SiteName" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Ejecutando en [$Target] de '$SiteName'..." -ForegroundColor Cyan
Write-Host "Contenedor: $containerId" -ForegroundColor DarkGray
Write-Host ""

if ($PhpCode) {
    # Para codigo PHP, usamos un archivo temporal en lugar de php -r
    # Esto evita problemas de escape de comillas complejas
    $fullPhpCode = "<?php`nrequire '/var/www/html/wp-load.php';`n$PhpCode"
    
    # Crear archivo temporal local
    $randomId = Get-Random
    $tempPhpFile = Join-Path $env:TEMP "exec_php_$randomId.php"
    $fullPhpCode | Out-File -FilePath $tempPhpFile -Encoding UTF8 -NoNewline
    
    # Obtener configuracion del VPS
    $vps = Get-VpsConfig
    $sshTarget = "$($vps.user)@$($vps.ip)"
    $remoteTemp = "/tmp/exec_$randomId.php"
    $containerPath = "/tmp/exec_$randomId.php"
    
    # Copiar archivo al VPS
    Write-Host "Preparando codigo PHP..." -ForegroundColor DarkGray
    scp $tempPhpFile "${sshTarget}:${remoteTemp}" 2>$null
    
    # Copiar al contenedor
    $copyResult = ssh $sshTarget "docker cp $remoteTemp ${containerId}:$containerPath" 2>&1
    
    # Ejecutar PHP
    $result = ssh $sshTarget "docker exec -u www-data $containerId php $containerPath" 2>&1
    
    # Limpiar
    ssh $sshTarget "docker exec $containerId rm -f $containerPath; rm -f $remoteTemp" 2>$null
    Remove-Item $tempPhpFile -Force -ErrorAction SilentlyContinue
    
    Write-Host $result
}
else {
    $result = Invoke-DockerExec -ContainerId $containerId -Command $Command
    Write-Host $result
}

Write-Host $result
Write-Host ""
