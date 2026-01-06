<#
.SYNOPSIS
    Despliega o actualiza el tema Glory en un sitio.
.DESCRIPTION
    Instala el tema Glory desde cero o actualiza uno existente.
    Soporta seleccion de ramas especificas.
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER GloryBranch
    Rama del tema Glory
.PARAMETER LibraryBranch
    Rama de la libreria Glory
.PARAMETER Update
    Actualiza en lugar de reinstalar (mas rapido)
.PARAMETER SkipReact
    Omite la compilacion de React
.EXAMPLE
    .\deploy-theme.ps1 -SiteName "padel" -GloryBranch "padel"
.EXAMPLE
    .\deploy-theme.ps1 -SiteName "nakomi" -Update
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [string]$GloryBranch,
    
    [string]$LibraryBranch,
    
    [switch]$Update,
    
    [switch]$SkipReact
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPressManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DESPLIEGUE DE TEMA GLORY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

<#
Validacion: Verificar que el sitio existe y tiene UUID configurado
#>
try {
    $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Iniciando despliegue de tema en: $SiteName" -Source "deploy-theme"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

if (-not $GloryBranch) { $GloryBranch = $sitio.gloryBranch }
if (-not $LibraryBranch) { $LibraryBranch = $sitio.libraryBranch }

$stackName = "$SiteName-stack"

Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Rama tema: $GloryBranch" -ForegroundColor White
Write-Host "Rama libreria: $LibraryBranch" -ForegroundColor White
Write-Host ""

if ($Update) {
    Write-Host "Modo: ACTUALIZACION (git pull)" -ForegroundColor Yellow
    Update-GloryTheme -StackName $stackName
}
else {
    Write-Host "Modo: INSTALACION COMPLETA" -ForegroundColor Yellow
    
    $params = @{
        StackName     = $stackName
        GloryBranch   = $GloryBranch
        LibraryBranch = $LibraryBranch
    }
    
    if ($SkipReact) {
        $params.SkipReact = $true
    }
    
    Install-GloryTheme @params
}

Write-Host ""
Write-Host "Tema desplegado exitosamente!" -ForegroundColor Green
Write-Host ""
