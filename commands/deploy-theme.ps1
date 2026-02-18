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
.PARAMETER Force
    Fuerza el despliegue con git reset --hard (destructivo)
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
    
    [switch]$SkipReact,

    [switch]$Force
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
$themeName = $sitio.themeName
if (-not $themeName) { $themeName = "glory" }

if (-not $SkipReact.IsPresent -and $sitio.skipReact) { 
    $SkipReact = $true 
    Write-Host "Configuracion de sitio: SkipReact ACTIVADO" -ForegroundColor Yellow
}

$stackUuid = $sitio.stackUuid

Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Rama tema: $GloryBranch" -ForegroundColor White
Write-Host "Rama libreria: $LibraryBranch" -ForegroundColor White
Write-Host "Carpeta tema: $themeName" -ForegroundColor White
Write-Host "Stack UUID: $stackUuid" -ForegroundColor DarkGray
if ($SkipReact) { Write-Host "Omitir React: SI" -ForegroundColor Yellow }
Write-Host ""

if ($Update) {
    Write-Host "Modo: ACTUALIZACION (git pull)" -ForegroundColor Yellow
    if ($Force) { Write-Host "MODO FORCE: RESET --HARD ACTIVADO" -ForegroundColor Red }
    Update-GloryTheme -StackUuid $stackUuid -ThemeName $themeName -GloryBranch $GloryBranch -LibraryBranch $LibraryBranch -Force:$Force -SkipReact:$SkipReact
}

else {
    Write-Host "Modo: INSTALACION COMPLETA" -ForegroundColor Yellow
    
    $params = @{
        StackUuid     = $stackUuid
        GloryBranch   = $GloryBranch
        LibraryBranch = $LibraryBranch
        ThemeName     = $themeName
    }
    
    if ($SkipReact) {
        $params.SkipReact = $true
    }
    
    Install-GloryTheme @params
}

<#
    Post-deploy para Kamples: composer install + npm build + env sync.
    Se ejecuta automaticamente si el sitio tiene template=kamples.
#>
if ($sitio.PSObject.Properties['template'] -and $sitio.template -eq "kamples") {
    Write-Host "" 
    Write-Host "Detectado template kamples - ejecutando pasos post-deploy..." -ForegroundColor Cyan
    
    Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
    $wpContainerId = Get-WordPressContainerId -Uuid $stackUuid
    
    if ($wpContainerId) {
        $postDeployScript = @"
#!/bin/bash
set -e
THEME_PATH="/var/www/html/wp-content/themes/$themeName"
cd \`$THEME_PATH

# Composer install (sin dev dependencies)
if [ -f composer.json ]; then
    echo "[INFO] composer install --no-dev..."
    export COMPOSER_NO_INTERACTION=1
    composer install --no-dev --optimize-autoloader
fi

# npm install + build (Vite)
if [ -f package.json ]; then
    echo "[INFO] npm install..."
    npm install
    echo "[INFO] npm run build..."
    npm run build
fi

chown -R www-data:www-data \`$THEME_PATH
echo "[SUCCESS] Post-deploy kamples completado"
"@
        Invoke-DockerExec -ContainerId $wpContainerId -Command $postDeployScript
    }
    else {
        Write-Host "WARN: No se encontro contenedor WordPress para post-deploy" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Tema desplegado exitosamente!" -ForegroundColor Green
Write-Host ""
