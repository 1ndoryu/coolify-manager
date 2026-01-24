<#
.SYNOPSIS
    Muestra el estado detallado de Git en el tema del sitio.
.DESCRIPTION
    Ejecuta un diagnostico completo de Git (status, branch, log basic)
    en el directorio del tema para identificar problemas de sincronizacion.
.PARAMETER SiteName
    Nombre del sitio
.EXAMPLE
    .\git-status.ps1 -SiteName "guillermo"
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPressManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

$SshModulePath = Join-Path $ModulesPath "SshOperations.psm1"
Write-Host "Importing module from: $SshModulePath" -ForegroundColor DarkGray
Import-Module $SshModulePath -Force -Verbose:$false

if (-not (Get-Command "Get-WordPressContainerId" -ErrorAction SilentlyContinue)) {
    Write-Host "CRITICAL ERROR: Function 'Get-WordPressContainerId' not found after import!" -ForegroundColor Red
    Write-Host "Available commands in SshOperations:"
    Get-Command -Module SshOperations | Select-Object -ExpandProperty Name | Write-Host
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTICO GIT: $SiteName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$themeName = $sitio.themeName
if (-not $themeName) { $themeName = "glory" }

$stackUuid = $sitio.stackUuid
$containerId = Get-WordPressContainerId -Uuid $stackUuid

if (-not $containerId) {
    Write-Host "No se encontro el contenedor." -ForegroundColor Red
    exit 1
}

Write-Host "Contenedor: $containerId" -ForegroundColor DarkGray
Write-Host "Tema: $themeName" -ForegroundColor DarkGray
Write-Host ""

$script = @"
#!/bin/bash
THEME_PATH="/var/www/html/wp-content/themes/$themeName"

if [ ! -d "`$THEME_PATH" ]; then
    echo "ERROR: No existe la carpeta `$THEME_PATH"
    exit 1
fi

cd `$THEME_PATH

echo -e "\n\033[1;33m--- BRANCH INFO ---\033[0m"
git branch -vv

echo -e "\n\033[1;33m--- STATUS SHORT ---\033[0m"
git status --short

echo -e "\n\033[1;33m--- REMOTE ---\033[0m"
git remote -v

echo -e "\n\033[1;33m--- LAST COMMIT ---\033[0m"
git log -1 --format="%h - %s (%cr)"

echo -e "\n\033[1;33m--- SUBMODULES ---\033[0m"
git submodule status
"@

Invoke-DockerExec -ContainerId $containerId -Command $script

Write-Host ""
Write-Host "Diagnostico finalizado." -ForegroundColor Green
Write-Host ""
