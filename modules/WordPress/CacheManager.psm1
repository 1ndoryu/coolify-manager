<#
.SYNOPSIS
    Modulo de gestion de cache headers para WordPress.
.DESCRIPTION
    Funciones para habilitar, deshabilitar y verificar headers de cache
    en archivos .htaccess de sitios WordPress desplegados en Coolify.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

<#
Marcadores para identificar las reglas de cache agregadas por el CLI
#>
$script:CacheStartMarker = "# === COOLIFY MANAGER CACHE START ==="
$script:CacheEndMarker = "# === COOLIFY MANAGER CACHE END ==="

<#
Reglas de cache HTTP recomendadas para WordPress
#>
$script:CacheRules = @"
$script:CacheStartMarker
# Generado automaticamente por Coolify Manager
# https://github.com/coolify-manager

<IfModule mod_expires.c>
    ExpiresActive On
    
    # Imagenes: 1 año (inmutables o versionadas)
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    
    # Fuentes: 1 año
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
    ExpiresByType application/font-woff2 "access plus 1 year"
    ExpiresByType application/font-woff "access plus 1 year"
    
    # CSS y JS: 1 mes (WordPress agrega ?ver= para cache busting)
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    
    # HTML: no cachear (contenido dinamico)
    ExpiresByType text/html "access plus 0 seconds"
</IfModule>

<IfModule mod_headers.c>
    # Archivos estaticos con cache-control
    <FilesMatch "\.(ico|pdf|jpg|jpeg|png|gif|webp|svg|js|css|woff|woff2|ttf)$">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </FilesMatch>
    
    # HTML sin cache
    <FilesMatch "\.(html|htm|php)$">
        Header set Cache-Control "no-cache, no-store, must-revalidate"
    </FilesMatch>
</IfModule>
$script:CacheEndMarker
"@

function Get-CacheStatus {
    <#
    .SYNOPSIS
        Verifica el estado de cache headers en un sitio
    .PARAMETER ContainerId
        ID del contenedor WordPress
    .PARAMETER SshTarget
        Target SSH (user@ip)
    .OUTPUTS
        Objeto con el estado del cache
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SshTarget
    )
    
    $htaccessPath = "/var/www/html/.htaccess"
    
    # Verificar si el archivo .htaccess existe
    $existsCmd = "docker exec $ContainerId test -f $htaccessPath && echo 'EXISTS' || echo 'NOT_EXISTS'"
    $existsResult = ssh $SshTarget $existsCmd 2>&1
    
    if ($existsResult.Trim() -eq "NOT_EXISTS") {
        return [PSCustomObject]@{
            HtaccessExists = $false
            CacheEnabled = $false
            ModExpiresEnabled = $null
            ModHeadersEnabled = $null
            Message = "Archivo .htaccess no existe"
        }
    }
    
    # Verificar si tiene nuestras reglas de cache
    $checkCmd = "docker exec $ContainerId grep -c 'COOLIFY MANAGER CACHE' $htaccessPath 2>/dev/null || echo '0'"
    $cacheResult = ssh $SshTarget $checkCmd 2>&1
    $cacheEnabled = ($cacheResult.Trim() -ne "0")
    
    # Verificar modulos de Apache
    $modulesCmd = "docker exec $ContainerId apache2ctl -M 2>/dev/null | grep -E '(expires|headers)_module' | wc -l"
    $modulesResult = ssh $SshTarget $modulesCmd 2>&1
    $modulesCount = [int]$modulesResult.Trim()
    
    return [PSCustomObject]@{
        HtaccessExists = $true
        CacheEnabled = $cacheEnabled
        ModExpiresEnabled = ($modulesCount -ge 1)
        ModHeadersEnabled = ($modulesCount -ge 2)
        ModulesCount = $modulesCount
        Message = if ($cacheEnabled) { "Cache headers configurados" } else { "Cache headers no configurados" }
    }
}

function Enable-CacheHeaders {
    <#
    .SYNOPSIS
        Habilita cache headers en el .htaccess
    .PARAMETER ContainerId
        ID del contenedor WordPress
    .PARAMETER SshTarget
        Target SSH (user@ip)
    .OUTPUTS
        $true si fue exitoso
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SshTarget
    )
    
    $htaccessPath = "/var/www/html/.htaccess"
    
    # Script PHP para agregar las reglas de cache de forma segura
    $phpScript = @'
<?php
$htaccessPath = '/var/www/html/.htaccess';
$cacheStartMarker = '# === COOLIFY MANAGER CACHE START ===';
$cacheEndMarker = '# === COOLIFY MANAGER CACHE END ===';

$cacheRules = <<<'CACHE'
# === COOLIFY MANAGER CACHE START ===
# Generado automaticamente por Coolify Manager

<IfModule mod_expires.c>
    ExpiresActive On
    
    # Imagenes: 1 año (inmutables o versionadas)
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    
    # Fuentes: 1 año
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
    ExpiresByType application/font-woff2 "access plus 1 year"
    ExpiresByType application/font-woff "access plus 1 year"
    
    # CSS y JS: 1 mes (WordPress agrega ?ver= para cache busting)
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    
    # HTML: no cachear (contenido dinamico)
    ExpiresByType text/html "access plus 0 seconds"
</IfModule>

<IfModule mod_headers.c>
    # Archivos estaticos con cache-control
    <FilesMatch "\.(ico|pdf|jpg|jpeg|png|gif|webp|svg|js|css|woff|woff2|ttf)$">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </FilesMatch>
    
    # HTML sin cache
    <FilesMatch "\.(html|htm|php)$">
        Header set Cache-Control "no-cache, no-store, must-revalidate"
    </FilesMatch>
</IfModule>
# === COOLIFY MANAGER CACHE END ===

CACHE;

// Leer contenido actual
$current = file_exists($htaccessPath) ? file_get_contents($htaccessPath) : '';

// Verificar si ya existe
if (strpos($current, 'COOLIFY MANAGER CACHE') !== false) {
    echo "ALREADY_CONFIGURED";
    exit(0);
}

// Crear backup
if (file_exists($htaccessPath)) {
    copy($htaccessPath, $htaccessPath . '.bak');
}

// Agregar reglas al inicio
$new = $cacheRules . $current;
file_put_contents($htaccessPath, $new);

echo "SUCCESS";
'@

    # Ejecutar el script PHP via base64
    $phpScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($phpScript))
    $execCmd = "docker exec $ContainerId bash -c 'echo $phpScriptBase64 | base64 -d | php'"
    
    $result = ssh $SshTarget $execCmd 2>&1
    
    return $result
}

function Disable-CacheHeaders {
    <#
    .SYNOPSIS
        Deshabilita cache headers removiendo las reglas del .htaccess
    .PARAMETER ContainerId
        ID del contenedor WordPress
    .PARAMETER SshTarget
        Target SSH (user@ip)
    .OUTPUTS
        Resultado de la operacion
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SshTarget
    )
    
    $phpScript = @'
<?php
$htaccessPath = '/var/www/html/.htaccess';

if (!file_exists($htaccessPath)) {
    echo "NOT_EXISTS";
    exit(0);
}

$content = file_get_contents($htaccessPath);

// Verificar si tiene nuestras reglas
if (strpos($content, 'COOLIFY MANAGER CACHE') === false) {
    echo "NOT_CONFIGURED";
    exit(0);
}

// Quitar el bloque de cache
$pattern = '/# === COOLIFY MANAGER CACHE START ===.*?# === COOLIFY MANAGER CACHE END ===\n*/s';
$newContent = preg_replace($pattern, '', $content);

// Guardar
file_put_contents($htaccessPath, $newContent);

echo "SUCCESS";
'@

    $phpScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($phpScript))
    $execCmd = "docker exec $ContainerId bash -c 'echo $phpScriptBase64 | base64 -d | php'"
    
    $result = ssh $SshTarget $execCmd 2>&1
    
    return $result
}

function Test-ApacheModules {
    <#
    .SYNOPSIS
        Verifica y habilita modulos de Apache necesarios
    .PARAMETER ContainerId
        ID del contenedor WordPress
    .PARAMETER SshTarget
        Target SSH (user@ip)
    .OUTPUTS
        Estado de los modulos
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$SshTarget
    )
    
    # Verificar modulos
    $checkCmd = "docker exec $ContainerId apache2ctl -M 2>/dev/null | grep -E '(expires|headers)_module'"
    $result = ssh $SshTarget $checkCmd 2>&1
    
    $hasExpires = $result -match "expires_module"
    $hasHeaders = $result -match "headers_module"
    
    if (-not $hasExpires -or -not $hasHeaders) {
        # Intentar habilitar modulos
        Write-Host "Habilitando modulos de Apache..." -ForegroundColor DarkGray
        
        if (-not $hasExpires) {
            $enableCmd = "docker exec $ContainerId a2enmod expires 2>/dev/null"
            ssh $SshTarget $enableCmd 2>&1 | Out-Null
        }
        
        if (-not $hasHeaders) {
            $enableCmd = "docker exec $ContainerId a2enmod headers 2>/dev/null"
            ssh $SshTarget $enableCmd 2>&1 | Out-Null
        }
        
        # Reiniciar Apache
        Write-Host "Reiniciando Apache..." -ForegroundColor DarkGray
        $restartCmd = "docker exec $ContainerId apache2ctl graceful 2>/dev/null"
        ssh $SshTarget $restartCmd 2>&1 | Out-Null
        
        return [PSCustomObject]@{
            ModulesEnabled = $true
            ApacheRestarted = $true
        }
    }
    
    return [PSCustomObject]@{
        ModulesEnabled = $true
        ApacheRestarted = $false
    }
}

Export-ModuleMember -Function @(
    'Get-CacheStatus',
    'Enable-CacheHeaders',
    'Disable-CacheHeaders',
    'Test-ApacheModules'
)
