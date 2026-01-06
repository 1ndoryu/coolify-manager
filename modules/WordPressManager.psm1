<#
.SYNOPSIS
    Modulo de gestion de WordPress en contenedores.
.DESCRIPTION
    Funciones para gestionar instalaciones WordPress dentro de contenedores Docker:
    instalar tema Glory, importar BD, corregir URLs, etc.
#>

$script:ModuleRoot = Split-Path -Parent $PSScriptRoot

Import-Module (Join-Path $PSScriptRoot "SshOperations.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Core\ConfigManager.psm1") -Force

function Get-GloryConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion del tema Glory
    #>
    $configPath = Join-Path $script:ModuleRoot "config\settings.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.glory
}

function Get-SiteConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion de un sitio especifico
    .PARAMETER SiteName
        Nombre del sitio
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $configPath = Join-Path $script:ModuleRoot "config\settings.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $site = $config.sitios | Where-Object { $_.nombre -eq $SiteName }
    
    if (-not $site) {
        throw "Sitio '$SiteName' no encontrado en la configuracion"
    }
    
    return $site
}

function Install-GloryTheme {
    <#
    .SYNOPSIS
        Instala el tema Glory en un contenedor WordPress
    .PARAMETER StackName
        Nombre del stack (ej: "padel-stack")
    .PARAMETER GloryBranch
        Rama del tema Glory a instalar
    .PARAMETER LibraryBranch
        Rama de la libreria Glory a instalar
    .PARAMETER CompileReact
        Si se debe compilar React (default: true)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [string]$GloryBranch = "main",
        
        [string]$LibraryBranch = "main",
        
        [switch]$SkipReact
    )
    
    $gloryConfig = Get-GloryConfig
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        throw "No se encontro contenedor WordPress para el stack: $StackName"
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

# Clonar tema Glory
cd /var/www/html/wp-content/themes
rm -rf glory
git clone -b $GloryBranch $($gloryConfig.templateRepo) glory

# Clonar libreria interna
cd glory
git clone -b $LibraryBranch $($gloryConfig.libraryRepo) Glory

# Instalar dependencias PHP
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
    
    Write-Host "Tema Glory instalado exitosamente!" -ForegroundColor Green
}

function Update-GloryTheme {
    <#
    .SYNOPSIS
        Actualiza el tema Glory (git pull + rebuild)
    .PARAMETER StackName
        Nombre del stack
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName
    )
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        throw "No se encontro contenedor WordPress para el stack: $StackName"
    }
    
    Write-Host "Actualizando tema Glory..." -ForegroundColor Yellow
    
    $updateScript = @"
cd /var/www/html/wp-content/themes/glory
git pull
cd Glory
git pull
composer install --no-dev
cd assets/react
npm install
npm run build
chown -R www-data:www-data /var/www/html/wp-content/themes/glory
"@
    
    Invoke-DockerExec -ContainerId $containerId -Command $updateScript
    Write-Host "Tema actualizado!" -ForegroundColor Green
}

function Set-WordPressUrls {
    <#
    .SYNOPSIS
        Corrige las URLs de WordPress (home y siteurl)
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER Domain
        Dominio nuevo (ej: https://mi-sitio.com)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$Domain
    )
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    $phpScript = @"
<?php
require '/var/www/html/wp-load.php';
update_option('home', '$Domain');
update_option('siteurl', '$Domain');
echo 'URLs actualizadas a: $Domain';
"@
    
    $tempFile = Join-Path $env:TEMP "fix_url_$(Get-Random).php"
    $phpScript | Out-File -FilePath $tempFile -Encoding UTF8
    
    Copy-FileToContainer -LocalPath $tempFile -ContainerId $containerId -ContainerPath "/var/www/html/fix_url.php"
    
    $result = Invoke-DockerExec -ContainerId $containerId -Command "php /var/www/html/fix_url.php" -User "www-data"
    Invoke-DockerExec -ContainerId $containerId -Command "rm /var/www/html/fix_url.php"
    
    Remove-Item $tempFile -Force
    
    Write-Host $result -ForegroundColor Green
}

function Import-WordPressDatabase {
    <#
    .SYNOPSIS
        Importa un archivo SQL a la base de datos del WordPress
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER SqlFilePath
        Ruta local al archivo .sql
    .PARAMETER DbName
        Nombre de la base de datos (default: wordpress)
    .PARAMETER SiteName
        Nombre del sitio (para obtener credenciales)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$SqlFilePath,
        
        [string]$DbName = "wordpress",
        
        [string]$SiteName
    )
    
    if (-not (Test-Path $SqlFilePath)) {
        throw "Archivo SQL no encontrado: $SqlFilePath"
    }
    
    $mariadbId = Get-MariaDbContainerId -StackName $StackName
    
    if (-not $mariadbId) {
        throw "No se encontro contenedor MariaDB para el stack: $StackName"
    }
    
    Write-Host "Importando base de datos..." -ForegroundColor Yellow
    
    Copy-FileToContainer -LocalPath $SqlFilePath -ContainerId $mariadbId -ContainerPath "/tmp/import.sql"
    
    <#
    Obtencion segura del password:
    1. Si se proporciona SiteName, usa Get-DbPassword
    2. Si no, intenta extraer el nombre del StackName (formato: nombre-stack)
    3. Busca en variables de entorno: DB_PASSWORD_SITENAME, COOLIFY_DB_PASSWORD
    4. Ultimo recurso: config file
    #>
    if (-not $SiteName) {
        $SiteName = $StackName -replace '-stack$', ''
    }
    
    try {
        $dbPassword = Get-DbPassword -SiteName $SiteName
    }
    catch {
        Write-Warning "No se encontro password especifico. Usando variable COOLIFY_DB_PASSWORD"
        $dbPassword = [System.Environment]::GetEnvironmentVariable("COOLIFY_DB_PASSWORD")
        if (-not $dbPassword) {
            throw "No se encontro password de BD. Configure COOLIFY_DB_PASSWORD o DB_PASSWORD_$($SiteName.ToUpper())"
        }
    }
    
    $importCmd = "mariadb -u manager -p'$dbPassword' $DbName < /tmp/import.sql && rm /tmp/import.sql"
    Invoke-DockerExec -ContainerId $mariadbId -Command $importCmd
    
    Write-Host "Base de datos importada exitosamente!" -ForegroundColor Green
}

function New-WordPressAdmin {
    <#
    .SYNOPSIS
        Crea un nuevo usuario administrador en WordPress
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER Username
        Nombre de usuario
    .PARAMETER Password
        Contrasena
    .PARAMETER Email
        Email del admin
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Password,
        
        [string]$Email = "admin@wandori.us"
    )
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    $phpScript = @"
<?php
require '/var/www/html/wp-load.php';
if (!username_exists('$Username')) {
    \`$user_id = wp_create_user('$Username', '$Password', '$Email');
    \`$user = new WP_User(\`$user_id);
    \`$user->set_role('administrator');
    echo 'Usuario administrador creado: $Username';
} else {
    echo 'El usuario ya existe: $Username';
}
"@
    
    $tempFile = Join-Path $env:TEMP "create_admin_$(Get-Random).php"
    $phpScript | Out-File -FilePath $tempFile -Encoding UTF8
    
    Copy-FileToContainer -LocalPath $tempFile -ContainerId $containerId -ContainerPath "/var/www/html/create_admin.php"
    
    $result = Invoke-DockerExec -ContainerId $containerId -Command "php /var/www/html/create_admin.php" -User "www-data"
    Invoke-DockerExec -ContainerId $containerId -Command "rm /var/www/html/create_admin.php"
    
    Remove-Item $tempFile -Force
    
    Write-Host $result -ForegroundColor Green
}

Export-ModuleMember -Function @(
    'Get-SiteConfig',
    'Install-GloryTheme',
    'Update-GloryTheme',
    'Set-WordPressUrls',
    'Import-WordPressDatabase',
    'New-WordPressAdmin'
)
