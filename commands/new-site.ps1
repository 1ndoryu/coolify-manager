<#
.SYNOPSIS
    Crea un nuevo sitio WordPress en Coolify.
.DESCRIPTION
    Automatiza la creacion completa de un sitio WordPress:
    1. Crea el stack en Coolify (WordPress + MariaDB)
    2. Despliega el stack
    3. Instala el tema Glory
    4. Configura las URLs correctas
.PARAMETER SiteName
    Nombre identificador del sitio (ej: "mi-proyecto")
.PARAMETER Domain
    Dominio completo con protocolo (ej: "https://mi-proyecto.com")
.PARAMETER GloryBranch
    Rama del tema Glory a usar (default: main)
.PARAMETER LibraryBranch
    Rama de la libreria Glory a usar (default: main)
.PARAMETER SkipTheme
    Omitir la instalacion del tema Glory
.EXAMPLE
    .\new-site.ps1 -SiteName "blog" -Domain "https://blog.wandori.us"
.EXAMPLE
    .\new-site.ps1 -SiteName "tienda" -Domain "https://tienda.com" -GloryBranch "ecommerce"
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [Parameter(Mandatory)]
    [string]$Domain,
    
    [string]$GloryBranch = "main",
    
    [string]$LibraryBranch = "main",
    
    [switch]$SkipTheme
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPressManager.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CREACION DE NUEVO SITIO WORDPRESS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Dominio: $Domain" -ForegroundColor White
Write-Host "Rama Glory: $GloryBranch" -ForegroundColor White
Write-Host ""

$stackName = "$SiteName-stack"

Write-Host "[1/4] Creando stack en Coolify..." -ForegroundColor Yellow
$stackResult = New-CoolifyWordPressStack -SiteName $SiteName -Domain $Domain

Write-Host ""
Write-Host "[2/4] Desplegando stack..." -ForegroundColor Yellow
Start-CoolifyService -Uuid $stackResult.uuid

Write-Host "Esperando 30 segundos para que los contenedores inicien..." -ForegroundColor DarkGray
Start-Sleep -Seconds 30

if (-not $SkipTheme) {
    Write-Host ""
    Write-Host "[3/4] Instalando tema Glory..." -ForegroundColor Yellow
    Install-GloryTheme -StackName $stackName -GloryBranch $GloryBranch -LibraryBranch $LibraryBranch
}
else {
    Write-Host "[3/4] Instalacion de tema omitida (flag -SkipTheme)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[4/4] Configurando URLs..." -ForegroundColor Yellow
Set-WordPressUrls -StackName $stackName -Domain $Domain

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SITIO CREADO EXITOSAMENTE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "UUID del Stack: $($stackResult.uuid)" -ForegroundColor Cyan
Write-Host "DB Password: $($stackResult.dbPassword)" -ForegroundColor Yellow
Write-Host "Root Password: $($stackResult.rootPassword)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Accede a: $Domain" -ForegroundColor White
Write-Host ""

$configPath = Join-Path $PSScriptRoot "..\config\settings.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$nuevoSitio = @{
    nombre        = $SiteName
    dominio       = $Domain
    stackUuid     = $stackResult.uuid
    gloryBranch   = $GloryBranch
    libraryBranch = $LibraryBranch
}

$config.sitios += $nuevoSitio
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

Write-Host "Sitio agregado a la configuracion local." -ForegroundColor DarkGray
