<#
.SYNOPSIS
    Modulo de gestion del tema Glory.
.DESCRIPTION
    Funciones para instalar, actualizar y configurar el tema Glory
    en contenedores WordPress.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "SshOperations.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\ConfigManager.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\Logger.psm1") -Force

function Get-GloryConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion del tema Glory desde el archivo de settings
    .OUTPUTS
        Objeto con la configuracion de Glory (templateRepo, libraryRepo)
    #>
    $config = Get-Config
    return $config.glory
}

function Install-GloryTheme {
    <#
    .SYNOPSIS
        Instala el tema Glory en un contenedor WordPress
    .DESCRIPTION
        Clona el repositorio del tema Glory, instala dependencias PHP y opcionalmente
        compila los assets React.
    .PARAMETER StackName
        Nombre del stack (ej: "padel-stack")
    .PARAMETER GloryBranch
        Rama del tema Glory a instalar (default: main)
    .PARAMETER LibraryBranch
        Rama de la libreria Glory a instalar (default: main)
    .PARAMETER SkipReact
        Si se especifica, omite la compilacion de React
    .EXAMPLE
        Install-GloryTheme -StackName "padel-stack" -GloryBranch "main"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [string]$GloryBranch = "main",
        
        [string]$LibraryBranch = "main",
        
        [switch]$SkipReact
    )
    
    Write-Log -Level INFO -Message "Instalando tema Glory en $StackName" -Source "Install-GloryTheme"
    
    $gloryConfig = Get-GloryConfig
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Source "Install-GloryTheme"
        throw $errorMsg
    }
    
    Write-Host "Instalando tema Glory en contenedor: $containerId" -ForegroundColor Green
    Write-Host "  - Rama tema: $GloryBranch" -ForegroundColor Cyan
    Write-Host "  - Rama libreria: $LibraryBranch" -ForegroundColor Cyan
    
    $installScript = @"
# Instalar dependencias del sistema
apt-get update && apt-get install -y unzip curl git

# Instalar Node.js
curl -sL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Instalar Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configurar git safe.directory
git config --global --add safe.directory /var/www/html/wp-content/themes/glory
git config --global --add safe.directory /var/www/html/wp-content/themes/glory/Glory

# Clonar tema Glory
cd /var/www/html/wp-content/themes
rm -rf glory
git clone -b $GloryBranch $($gloryConfig.templateRepo) glory

# Clonar libreria interna
cd /var/www/html/wp-content/themes/glory
git clone -b $LibraryBranch $($gloryConfig.libraryRepo) Glory

# Instalar dependencias PHP
cd /var/www/html/wp-content/themes/glory
composer install --no-dev --optimize-autoloader

# Corregir permisos
chown -R www-data:www-data /var/www/html/wp-content/themes/glory
"@

    Write-Host "Ejecutando instalacion de dependencias..." -ForegroundColor Yellow
    Invoke-DockerExec -ContainerId $containerId -Command $installScript
    
    if (-not $SkipReact) {
        Write-Host "Compilando React..." -ForegroundColor Yellow
        $reactScript = @"
cd /var/www/html/wp-content/themes/glory/Glory/assets/react
npm install
npm run build
chown -R www-data:www-data /var/www/html/wp-content/themes/glory
"@
        Invoke-DockerExec -ContainerId $containerId -Command $reactScript
    }
    
    Write-Log -Level INFO -Message "Tema Glory instalado exitosamente en $StackName" -Source "Install-GloryTheme"
    Write-Host "Tema Glory instalado exitosamente!" -ForegroundColor Green
}

function Update-GloryTheme {
    <#
    .SYNOPSIS
        Actualiza el tema Glory (git pull + rebuild)
    .DESCRIPTION
        Ejecuta git pull en el tema y la libreria, reinstala dependencias
        y recompila los assets React.
    .PARAMETER StackName
        Nombre del stack
    .EXAMPLE
        Update-GloryTheme -StackName "padel-stack"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName
    )
    
    Write-Log -Level INFO -Message "Actualizando tema Glory en $StackName" -Source "Update-GloryTheme"
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Source "Update-GloryTheme"
        throw $errorMsg
    }
    
    Write-Host "Actualizando tema Glory..." -ForegroundColor Yellow
    
    <# 
     Script que verifica e instala dependencias si no existen.
     Esto corrige el bug donde el update fallaba silenciosamente
     porque git/npm/composer no estaban instalados en el contenedor.
    #>
    $updateScript = @'
#!/bin/bash
set -e

# Verificar e instalar git si no existe
if [ ! -x "$(command -v git)" ]; then
    echo "[INFO] Instalando git..."
    apt-get update && apt-get install -y git
fi

# Verificar e instalar node si no existe
if [ ! -x "$(command -v node)" ]; then
    echo "[INFO] Instalando Node.js..."
    apt-get update
    apt-get install -y curl
    curl -sL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Verificar e instalar composer si no existe
if [ ! -x "$(command -v composer)" ]; then
    echo "[INFO] Instalando Composer..."
    apt-get install -y unzip
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Configurar git safe.directory
git config --global --add safe.directory /var/www/html/wp-content/themes/glory
git config --global --add safe.directory /var/www/html/wp-content/themes/glory/Glory

# Actualizar tema principal
echo "[INFO] Actualizando tema principal..."
cd /var/www/html/wp-content/themes/glory
git pull

# Actualizar libreria Glory
echo "[INFO] Actualizando libreria Glory..."
cd /var/www/html/wp-content/themes/glory/Glory
git pull

# Instalar dependencias PHP
echo "[INFO] Instalando dependencias PHP..."
cd /var/www/html/wp-content/themes/glory
composer install --no-dev --optimize-autoloader

# Compilar React
echo "[INFO] Compilando React..."
cd /var/www/html/wp-content/themes/glory/Glory/assets/react
npm install
npm run build

# Corregir permisos
echo "[INFO] Corrigiendo permisos..."
chown -R www-data:www-data /var/www/html/wp-content/themes/glory

echo "[SUCCESS] Actualizacion completada!"
'@
    
    $result = Invoke-DockerExec -ContainerId $containerId -Command $updateScript
    
    # Mostrar output del script
    if ($result) {
        Write-Host $result -ForegroundColor Gray
    }
    
    # Verificar si hubo error (buscar [SUCCESS] en el output)
    if ($result -notmatch "\[SUCCESS\]") {
        Write-Log -Level WARN -Message "La actualizacion puede haber fallado. Revisa el output anterior." -Source "Update-GloryTheme"
        Write-Host "Advertencia: La actualizacion puede haber fallado. Revisa el output." -ForegroundColor Yellow
    }
    else {
        Write-Log -Level INFO -Message "Tema Glory actualizado en $StackName" -Source "Update-GloryTheme"
        Write-Host "Tema actualizado exitosamente!" -ForegroundColor Green
    }
}

Export-ModuleMember -Function @(
    'Get-GloryConfig',
    'Install-GloryTheme',
    'Update-GloryTheme'
)
