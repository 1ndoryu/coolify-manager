<#
.SYNOPSIS
    Actualiza el dominio de un sitio.
.DESCRIPTION
    Actualiza la configuracion local (settings.json) y las URLs en la base de datos de WordPress.
    NOTA: No actualiza la configuracion de proxy en Coolify automaticamente (aun).
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER Domain
    Nuevo dominio (con https://)
.EXAMPLE
    .\set-domain.ps1 -SiteName "padel" -Domain "https://materialdepadel.es"
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [Parameter(Mandatory)]
    [string]$Domain
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"
$ConfigPath = Join-Path $PSScriptRoot "..\config\settings.json"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPressManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ACTUALIZACION DE DOMINIO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Leer configuracion actual
if (-not (Test-Path $ConfigPath)) {
    Write-Error "No se encontro el archivo de configuracion: $ConfigPath"
    exit 1
}

$jsonItems = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$sites = $jsonItems.sitios

# 2. Buscar el sitio
$siteData = $sites | Where-Object { $_.nombre -eq $SiteName }

if (-not $siteData) {
    Write-Error "Sitio '$SiteName' no encontrado en la configuracion."
    exit 1
}

$oldDomain = $siteData.dominio
Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Dominio actual: $oldDomain" -ForegroundColor Yellow
Write-Host "Nuevo dominio:  $Domain" -ForegroundColor Green
Write-Host ""

# 3. Actualizar en settings.json
$siteData.dominio = $Domain
$jsonContent = $jsonItems | ConvertTo-Json -Depth 10
$jsonContent | Out-File -FilePath $ConfigPath -Encoding UTF8

Write-Host "[OK] Configuracion local actualizada." -ForegroundColor Green

# 4. Actualizar en WordPress
try {
    # El nombre del stack suele ser "nombre-stack"
    $stackName = "$SiteName-stack"
    
    # Verificar si el stack tiene UUID antes de intentar conectar
    if (-not $siteData.stackUuid) {
        Write-Warning "El sitio no tiene UUID de stack asignado. No se pueden actualizar las URLs en WordPress."
        exit 0
    }

    Write-Host "Actualizando URLs en base de datos WordPress..." -ForegroundColor White
    Set-WordPressUrls -StackName $stackName -Domain $Domain -StackUuid $siteData.stackUuid
    Write-Host "[OK] URLs de WordPress actualizadas." -ForegroundColor Green
}
catch {
    Write-Error "Error actualizando WordPress: $($_.Exception.Message)"
    # No salimos con error fatal porque ya actualizamos el json local
}

Write-Host ""
Write-Host "NOTA IMPORTANTE:" -ForegroundColor Magenta
Write-Host "Este comando ha actualizado:"
Write-Host "1. La configuracion local (settings.json)"
Write-Host "2. Las opciones 'siteurl' y 'home' en la base de datos de WordPress"
Write-Host ""
Write-Host "AUN DEBES:" -ForegroundColor Yellow
Write-Host "1. Ir al panel de Coolify"
Write-Host "2. Cambiar el dominio en la configuracion del servicio/proxy"
Write-Host "3. Configurar los registros DNS para el nuevo dominio"
Write-Host ""
