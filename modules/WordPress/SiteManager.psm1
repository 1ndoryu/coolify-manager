<#
.SYNOPSIS
    Modulo de gestion de configuracion de sitios WordPress.
.DESCRIPTION
    Funciones para gestionar la configuracion de sitios WordPress:
    URLs, usuarios administradores, opciones generales.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "SshOperations.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\ConfigManager.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\Logger.psm1") -Force

function Get-SiteConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion de un sitio especifico desde settings.json
    .PARAMETER SiteName
        Nombre del sitio (ej: "padel", "nakomi")
    .OUTPUTS
        Objeto con la configuracion del sitio (nombre, url, stackUuid, etc.)
    .EXAMPLE
        $config = Get-SiteConfig -SiteName "padel"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $config = Get-Config
    $site = $config.sitios | Where-Object { $_.nombre -eq $SiteName }
    
    if (-not $site) {
        $availableSites = ($config.sitios | ForEach-Object { $_.nombre }) -join ", "
        $errorMsg = "Sitio '$SiteName' no encontrado. Sitios disponibles: $availableSites"
        Write-Log -Level ERROR -Message $errorMsg -Command "Get-SiteConfig"
        throw $errorMsg
    }
    
    return $site
}

function Set-WordPressUrls {
    <#
    .SYNOPSIS
        Corrige las URLs de WordPress (home y siteurl)
    .DESCRIPTION
        Actualiza las opciones 'home' y 'siteurl' en la base de datos de WordPress
        para reflejar el nuevo dominio.
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER Domain
        Dominio nuevo con protocolo (ej: https://mi-sitio.com)
    .EXAMPLE
        Set-WordPressUrls -StackName "padel-stack" -Domain "https://padel.wandori.us"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$Domain
    )
    
    Write-Log -Level INFO -Message "Actualizando URLs de $StackName a $Domain" -Command "Set-WordPressUrls"
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Command "Set-WordPressUrls"
        throw $errorMsg
    }
    
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
    
    Write-Log -Level INFO -Message "URLs actualizadas para $StackName" -Command "Set-WordPressUrls"
    Write-Host $result -ForegroundColor Green
}

function New-WordPressAdmin {
    <#
    .SYNOPSIS
        Crea un nuevo usuario administrador en WordPress
    .DESCRIPTION
        Crea un nuevo usuario con rol de administrador en la instalacion WordPress.
        Si el usuario ya existe, muestra un mensaje informativo.
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER Username
        Nombre de usuario para el admin
    .PARAMETER Password
        Contrasena del admin
    .PARAMETER Email
        Email del admin (default: admin@wandori.us)
    .EXAMPLE
        New-WordPressAdmin -StackName "padel-stack" -Username "admin" -Password "securepass123"
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
    
    Write-Log -Level INFO -Message "Creando admin '$Username' en $StackName" -Command "New-WordPressAdmin"
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        $errorMsg = "No se encontro contenedor WordPress para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Command "New-WordPressAdmin"
        throw $errorMsg
    }
    
    $phpScript = @"
<?php
require '/var/www/html/wp-load.php';
if (!username_exists('$Username')) {
    `$user_id = wp_create_user('$Username', '$Password', '$Email');
    `$user = new WP_User(`$user_id);
    `$user->set_role('administrator');
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
    
    Write-Log -Level INFO -Message "Admin creado/verificado en $StackName" -Command "New-WordPressAdmin"
    Write-Host $result -ForegroundColor Green
}

function Get-WordPressOption {
    <#
    .SYNOPSIS
        Obtiene el valor de una opcion de WordPress
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER OptionName
        Nombre de la opcion (ej: siteurl, home, blogname)
    .EXAMPLE
        Get-WordPressOption -StackName "padel-stack" -OptionName "siteurl"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$OptionName
    )
    
    $containerId = Get-WordPressContainerId -StackName $StackName
    
    if (-not $containerId) {
        throw "No se encontro contenedor WordPress para el stack: $StackName"
    }
    
    $phpScript = @"
<?php
require '/var/www/html/wp-load.php';
echo get_option('$OptionName');
"@
    
    $tempFile = Join-Path $env:TEMP "get_option_$(Get-Random).php"
    $phpScript | Out-File -FilePath $tempFile -Encoding UTF8
    
    Copy-FileToContainer -LocalPath $tempFile -ContainerId $containerId -ContainerPath "/var/www/html/get_option.php"
    
    $result = Invoke-DockerExec -ContainerId $containerId -Command "php /var/www/html/get_option.php" -User "www-data"
    Invoke-DockerExec -ContainerId $containerId -Command "rm /var/www/html/get_option.php"
    
    Remove-Item $tempFile -Force
    
    return $result
}

Export-ModuleMember -Function @(
    'Get-SiteConfig',
    'Set-WordPressUrls',
    'New-WordPressAdmin',
    'Get-WordPressOption'
)
