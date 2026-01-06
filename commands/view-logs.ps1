<#
.SYNOPSIS
    Muestra los logs de un sitio WordPress.
.DESCRIPTION
    Obtiene y muestra los logs del contenedor WordPress o MariaDB.
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER Lines
    Numero de lineas a mostrar (default: 50)
.PARAMETER Target
    Contenedor objetivo: wordpress o mariadb (default: wordpress)
.PARAMETER Follow
    Sigue los logs en tiempo real (Ctrl+C para salir)
.EXAMPLE
    .\view-logs.ps1 -SiteName "padel"
.EXAMPLE
    .\view-logs.ps1 -SiteName "nakomi" -Lines 100 -Target mariadb
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [int]$Lines = 50,
    
    [ValidateSet("wordpress", "mariadb")]
    [string]$Target = "wordpress",
    
    [switch]$Follow
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
    Write-Log -Level "DEBUG" -Message "Obteniendo logs de: $SiteName ($Target)" -Source "view-logs"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$stackName = "$SiteName-stack"

if ($Target -eq "wordpress") {
    $containerId = Get-WordPressContainerId -StackName $stackName
}
else {
    $containerId = Get-MariaDbContainerId -StackName $stackName
}

if (-not $containerId) {
    Write-Log -Level "ERROR" -Message "Contenedor $Target no encontrado para: $SiteName" -Source "view-logs"
    Write-Host "No se encontro contenedor $Target para: $SiteName" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Logs de [$Target] - $SiteName" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

if ($Follow) {
    Write-Host "(Presiona Ctrl+C para salir)" -ForegroundColor DarkGray
    Write-Host ""
    
    $vps = Get-VpsConfig
    ssh "$($vps.user)@$($vps.ip)" "docker logs -f --tail $Lines $containerId"
}
else {
    $logs = Get-ContainerLogs -ContainerId $containerId -Lines $Lines
    Write-Host $logs
}

Write-Host ""
