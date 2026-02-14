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
    .PARAMETER StackUuid
        UUID del stack de Coolify
    .PARAMETER GloryBranch
        Rama del tema Glory a instalar (default: main)
    .PARAMETER LibraryBranch
        Rama de la libreria Glory a instalar (default: main)
    .PARAMETER ThemeName
        Nombre de la carpeta del tema en el servidor (default: glory)
    .PARAMETER SkipReact
        Si se especifica, omite la compilacion de React
    .EXAMPLE
        Install-GloryTheme -StackUuid "zkcc040cc0scock4kcooowkc" -GloryBranch "main" -ThemeName "Padel"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackUuid,
        
        [string]$GloryBranch = "main",
        
        [string]$LibraryBranch = "main",
        
        [string]$ThemeName = "glory",
        
        [switch]$SkipReact
    )
    
    Write-Log -Level INFO -Message "Instalando tema Glory (UUID: $StackUuid, ThemeName: $ThemeName)" -Source "Install-GloryTheme"
    
    $gloryConfig = Get-GloryConfig
    $containerId = Get-WordPressContainerId -Uuid $StackUuid
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress para UUID: $StackUuid"
        Write-Log -Level ERROR -Message $errorMsg -Source "Install-GloryTheme"
        throw $errorMsg
    }
    
    Write-Host "Instalando tema Glory en contenedor: $containerId" -ForegroundColor Green
    Write-Host "  - Rama tema: $GloryBranch" -ForegroundColor Cyan
    Write-Host "  - Rama libreria: $LibraryBranch" -ForegroundColor Cyan
    Write-Host "  - Carpeta tema: $ThemeName" -ForegroundColor Cyan
    
    $templateRepo = $gloryConfig.templateRepo
    $libraryRepo = $gloryConfig.libraryRepo
    
    $installScript = @"
#!/bin/bash
set -e

# Evitar prompts interactivos
export GIT_TERMINAL_PROMPT=0
export COMPOSER_NO_INTERACTION=1
export DEBIAN_FRONTEND=noninteractive

THEME_NAME="$ThemeName"
THEME_PATH="/var/www/html/wp-content/themes/`$THEME_NAME"
LIBRARY_PATH="`$THEME_PATH/Glory"

echo "[INFO] Instalando tema: `$THEME_NAME"

# Instalar dependencias del sistema
apt-get update && apt-get install -y unzip curl git

# Instalar Node.js
curl -sL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Instalar Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configurar git safe.directory
git config --global --add safe.directory `$THEME_PATH
git config --global --add safe.directory `$LIBRARY_PATH

# Clonar tema Glory
cd /var/www/html/wp-content/themes
rm -rf `$THEME_NAME
git clone -b $GloryBranch $templateRepo `$THEME_NAME

# Clonar libreria interna
cd `$THEME_PATH
git clone -b $LibraryBranch $libraryRepo Glory

# Instalar dependencias PHP
cd `$THEME_PATH
composer install --no-dev --optimize-autoloader

# Corregir permisos
chown -R www-data:www-data `$THEME_PATH

echo "[SUCCESS] Instalacion base completada!"
"@

    Write-Host "Ejecutando instalacion de dependencias..." -ForegroundColor Yellow
    Invoke-DockerExec -ContainerId $containerId -Command $installScript
    
    if (-not $SkipReact) {
        Write-Host "Compilando React..." -ForegroundColor Yellow
        $reactScript = @"
#!/bin/bash
set -e
THEME_PATH="/var/www/html/wp-content/themes/$ThemeName"
cd `$THEME_PATH/Glory/assets/react
npm install
npm run build
chown -R www-data:www-data `$THEME_PATH
echo "[SUCCESS] React compilado!"
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
        Nombre del stack (fallback si no hay UUID)
    .PARAMETER StackUuid
        UUID del stack de Coolify (preferido)
    .PARAMETER ThemeName
        Nombre de la carpeta del tema en el servidor (default: glory)
    .EXAMPLE
        Update-GloryTheme -StackUuid "zkcc040cc0scock4kcooowkc" -ThemeName "Padel"
    #>
    param(
        [string]$StackName,
        
        [string]$StackUuid,
        
        [string]$ThemeName = "glory",
        
        [string]$GloryBranch = "main",

        [string]$LibraryBranch = "main",

    [switch]$Force,
        
        [switch]$SkipReact
    )
    
    Write-Log -Level INFO -Message "Actualizando tema Glory (ThemeName: $ThemeName, UUID: $StackUuid)" -Source "Update-GloryTheme"
    
    # Buscar contenedor usando UUID (preferido) o StackName (fallback)
    if ($StackUuid) {
        $containerId = Get-WordPressContainerId -Uuid $StackUuid
    }
    elseif ($StackName) {
        $containerId = Get-WordPressContainerId -StackName $StackName
    }
    else {
        throw "Debe especificar StackName o StackUuid"
    }
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress (UUID: $StackUuid, Stack: $StackName)"
        Write-Log -Level ERROR -Message $errorMsg -Source "Update-GloryTheme"
        throw $errorMsg
    }
    
    $gloryConfig = Get-GloryConfig
    $libraryRepo = $gloryConfig.libraryRepo

    Write-Host "Contenedor encontrado: $containerId" -ForegroundColor Gray
    Write-Host "Actualizando tema Glory (carpeta: $ThemeName)..." -ForegroundColor Yellow
    
    <# 
     Script que verifica e instala dependencias si no existen.
     Esto corrige el bug donde el update fallaba silenciosamente
     porque git/npm/composer no estaban instalados en el contenedor.
     
     CORRECCION: Usa ThemeName dinamico en lugar de 'glory' hardcodeado.
     VALIDACION: Verifica que la carpeta existe antes de continuar.
    #>
    $updateScript = @"
#!/bin/bash
set -e

# Evitar prompts interactivos
export GIT_TERMINAL_PROMPT=0
export COMPOSER_NO_INTERACTION=1
export DEBIAN_FRONTEND=noninteractive

THEME_NAME="$ThemeName"
THEME_PATH="/var/www/html/wp-content/themes/`$THEME_NAME"
LIBRARY_PATH="`$THEME_PATH/Glory"
THEMES_DIR="/var/www/html/wp-content/themes"


GLORY_BRANCH="$GloryBranch"
LIBRARY_BRANCH="$LibraryBranch"
LIBRARY_REPO="$libraryRepo"

echo "[INFO] Tema: `$THEME_NAME"
echo "[INFO] Ruta tema: `$THEME_PATH"
echo "[INFO] Ruta libreria: `$LIBRARY_PATH"

# ===========================================
# VALIDACION: Verificar que la carpeta existe
# ===========================================
if [ ! -d "`$THEME_PATH" ]; then
    echo ""
    echo "[ERROR] =========================================="
    echo "[ERROR] LA CARPETA DEL TEMA NO EXISTE!"
    echo "[ERROR] Buscando: `$THEME_PATH"
    echo "[ERROR] =========================================="
    echo ""
    echo "[INFO] Carpetas disponibles en `$THEMES_DIR:"
    ls -la `$THEMES_DIR | grep "^d" | awk '{print "  - " `$NF}'
    echo ""
    echo "[SOLUCION] Verifica el campo 'themeName' en settings.json"
    echo "[SOLUCION] El valor actual es: `$THEME_NAME"
    exit 1
fi

if [ ! -d "`$LIBRARY_PATH" ]; then
    echo ""
    echo "[ERROR] =========================================="
    echo "[ERROR] LA CARPETA DE LA LIBRERIA GLORY NO EXISTE!"
    echo "[ERROR] Buscando: `$LIBRARY_PATH"
    echo "[ERROR] =========================================="
    echo ""
    echo "[INFO] Contenido de `$THEME_PATH:"
    ls -la `$THEME_PATH
    echo ""
    echo "[SOLUCION] Ejecuta 'Install-GloryTheme' para clonar la libreria"
    exit 1
fi

echo "[OK] Carpetas validadas correctamente"

# Verificar e instalar git si no existe
if [ ! -x "`$(command -v git)" ]; then
    echo "[INFO] Instalando git..."
    apt-get update && apt-get install -y git
fi

# Verificar e instalar node si no existe
if [ ! -x "`$(command -v node)" ]; then
    echo "[INFO] Instalando Node.js..."
    apt-get update
    apt-get install -y curl
    curl -sL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Verificar e instalar composer si no existe
if [ ! -x "`$(command -v composer)" ]; then
    echo "[INFO] Instalando Composer..."
    apt-get install -y unzip
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Configurar git safe.directory y comportamiento de pull
git config --global --add safe.directory `$THEME_PATH
git config --global --add safe.directory `$LIBRARY_PATH
git config --global pull.rebase false
git config --global user.email "manager@coolify.bot"
git config --global user.name "Coolify Manager"

# Actualizar tema principal
echo "[INFO] Actualizando tema principal..."
cd `$THEME_PATH

if [ "$Force" = "True" ]; then
    echo "[WARN] Realizando HARD RESET a origin/`$GLORY_BRANCH..."
    git fetch --all
    git reset --hard "origin/`$GLORY_BRANCH"
else
    git pull
fi

# Actualizar libreria Glory
echo "[INFO] Actualizando libreria Glory (`$LIBRARY_BRANCH)..."

if [ ! -d "`$LIBRARY_PATH/.git" ]; then
    echo "[WARN] La libreria no es un repositorio git valido o no tiene .git."
    echo "[INFO] Re-clonando libreria desde `$LIBRARY_REPO..."
    cd "`$THEME_PATH"
    rm -rf Glory
    git clone -b `$LIBRARY_BRANCH `$LIBRARY_REPO Glory
else
    cd `$LIBRARY_PATH
    git fetch --all
    git checkout `$LIBRARY_BRANCH
    
    if [ "$Force" = "True" ]; then
        echo "[WARN] Realizando HARD RESET libreria a origin/`$LIBRARY_BRANCH..."
        git reset --hard "origin/`$LIBRARY_BRANCH"
    else
        git pull origin `$LIBRARY_BRANCH
    fi
fi


# Instalar dependencias PHP
echo "[INFO] Instalando dependencias PHP..."
cd `$THEME_PATH
composer install --no-dev --optimize-autoloader
"@

    $reactScript = @"
# Compilar React
echo "[INFO] Compilando React..."
cd `$LIBRARY_PATH/assets/react
npm install
npm run build
"@
    
    # Construir el script final combinando update y opcionalmente react
    if (-not $SkipReact) {
         $finalScript = $updateScript + "`n" + $reactScript
    } else {
         $finalScript = $updateScript + "`n echo '[INFO] Saltando compilacion de React'"
    }

    $finalScript += @"
    
# Corregir permisos
echo "[INFO] Corrigiendo permisos..."
chown -R www-data:www-data `$THEME_PATH

echo "[SUCCESS] Actualizacion completada!"
"@
    
    $result = Invoke-DockerExec -ContainerId $containerId -Command $finalScript


    
    # El output ya se mostro en tiempo real via Invoke-DockerExec
    
    # Verificar si hubo exito (buscar [SUCCESS] en el output)
    if ($result -like "*[SUCCESS]*") {
        Write-Log -Level INFO -Message "Tema Glory actualizado en $StackName" -Source "Update-GloryTheme"
        Write-Host "Tema actualizado exitosamente!" -ForegroundColor Green
    }
    else {
        Write-Log -Level WARN -Message "La actualizacion puede haber fallado. Revisa el output anterior." -Source "Update-GloryTheme"
        Write-Host "Advertencia: La actualizacion puede haber fallado. Revisa el output." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function @(
    'Get-GloryConfig',
    'Install-GloryTheme',
    'Update-GloryTheme'
)
