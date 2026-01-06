<#
.SYNOPSIS
    Modulo de gestion de configuracion.
.DESCRIPTION
    Maneja la configuracion del sistema, incluyendo carga de archivos,
    obtencion de credenciales desde variables de entorno, y gestion de sitios.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:ConfigCache = $null

function Get-ConfigFilePath {
    <#
    .SYNOPSIS
        Obtiene la ruta al archivo de configuracion
    .DESCRIPTION
        Busca primero settings.local.json, luego settings.json
    #>
    $localPath = Join-Path $script:ModuleRoot "config\settings.local.json"
    $defaultPath = Join-Path $script:ModuleRoot "config\settings.json"
    
    if (Test-Path $localPath) {
        return $localPath
    }
    
    if (Test-Path $defaultPath) {
        return $defaultPath
    }
    
    throw "No se encontro archivo de configuracion en: $localPath o $defaultPath"
}

function Get-Config {
    <#
    .SYNOPSIS
        Obtiene la configuracion completa
    .PARAMETER Force
        Si se fuerza la recarga del cache
    #>
    param(
        [switch]$Force
    )
    
    if ($script:ConfigCache -and -not $Force) {
        return $script:ConfigCache
    }
    
    $configPath = Get-ConfigFilePath
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    $config = Expand-ConfigVariables -Config $config
    
    $script:ConfigCache = $config
    return $config
}

function Expand-ConfigVariables {
    <#
    .SYNOPSIS
        Expande variables de entorno en la configuracion
    .DESCRIPTION
        Reemplaza ${VAR_NAME} con el valor de la variable de entorno
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )
    
    $json = $Config | ConvertTo-Json -Depth 10
    
    $pattern = '\$\{([^}]+)\}'
    $matches = [regex]::Matches($json, $pattern)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        $envValue = [System.Environment]::GetEnvironmentVariable($varName)
        
        if ($envValue) {
            $json = $json -replace [regex]::Escape($match.Value), $envValue
        }
    }
    
    return $json | ConvertFrom-Json
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
    
    $config = Get-Config
    $site = $config.sitios | Where-Object { $_.nombre -eq $SiteName }
    
    if (-not $site) {
        $disponibles = ($config.sitios | ForEach-Object { $_.nombre }) -join ", "
        throw "Sitio '$SiteName' no encontrado. Disponibles: $disponibles"
    }
    
    return $site
}

function Get-VpsConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion del VPS
    #>
    $config = Get-Config
    return $config.vps
}

function Get-CoolifyConfig {
    <#
    .SYNOPSIS
        Obtiene la configuracion de Coolify
    #>
    $config = Get-Config
    return $config.coolify
}

function Get-Credential {
    <#
    .SYNOPSIS
        Obtiene una credencial de forma segura
    .DESCRIPTION
        Busca primero en variables de entorno, luego en el archivo de config
    .PARAMETER Key
        Clave de la credencial (ej: COOLIFY_API_TOKEN, DB_PASSWORD_PADEL)
    .PARAMETER Fallback
        Valor por defecto si no se encuentra
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [string]$Fallback = $null
    )
    
    $envValue = [System.Environment]::GetEnvironmentVariable($Key)
    
    if ($envValue) {
        return $envValue
    }
    
    if ($Fallback) {
        return $Fallback
    }
    
    throw "Credencial '$Key' no encontrada en variables de entorno"
}

function Get-DbPassword {
    <#
    .SYNOPSIS
        Obtiene el password de la base de datos para un sitio
    .PARAMETER SiteName
        Nombre del sitio
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $envKey = "DB_PASSWORD_$($SiteName.ToUpper())"
    $envValue = [System.Environment]::GetEnvironmentVariable($envKey)
    
    if ($envValue) {
        return $envValue
    }
    
    $genericKey = "COOLIFY_DB_PASSWORD"
    $genericValue = [System.Environment]::GetEnvironmentVariable($genericKey)
    
    if ($genericValue) {
        return $genericValue
    }
    
    $config = Get-Config
    if ($config.wordpress.dbPassword) {
        return $config.wordpress.dbPassword
    }
    
    throw "Password de BD no encontrado. Configure la variable de entorno: $envKey o $genericKey"
}

function Get-AllSites {
    <#
    .SYNOPSIS
        Obtiene todos los sitios configurados
    #>
    $config = Get-Config
    return $config.sitios
}

function Add-Site {
    <#
    .SYNOPSIS
        Agrega un nuevo sitio a la configuracion
    .PARAMETER SiteConfig
        Objeto con la configuracion del sitio
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$SiteConfig
    )
    
    $configPath = Get-ConfigFilePath
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    $existing = $config.sitios | Where-Object { $_.nombre -eq $SiteConfig.nombre }
    if ($existing) {
        throw "El sitio '$($SiteConfig.nombre)' ya existe"
    }
    
    $config.sitios += $SiteConfig
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    
    $script:ConfigCache = $null
}

function Remove-Site {
    <#
    .SYNOPSIS
        Elimina un sitio de la configuracion
    .PARAMETER SiteName
        Nombre del sitio a eliminar
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $configPath = Get-ConfigFilePath
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    $config.sitios = @($config.sitios | Where-Object { $_.nombre -ne $SiteName })
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    
    $script:ConfigCache = $null
}

function Set-SiteConfig {
    <#
    .SYNOPSIS
        Actualiza la configuracion de un sitio
    .PARAMETER SiteName
        Nombre del sitio
    .PARAMETER Config
        Nueva configuracion (parcial o completa)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )
    
    $configPath = Get-ConfigFilePath
    $fullConfig = Get-Content $configPath -Raw | ConvertFrom-Json
    
    $siteIndex = -1
    for ($i = 0; $i -lt $fullConfig.sitios.Count; $i++) {
        if ($fullConfig.sitios[$i].nombre -eq $SiteName) {
            $siteIndex = $i
            break
        }
    }
    
    if ($siteIndex -eq -1) {
        throw "Sitio '$SiteName' no encontrado"
    }
    
    $currentSite = $fullConfig.sitios[$siteIndex]
    
    foreach ($prop in $Config.PSObject.Properties) {
        $currentSite | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
    }
    
    $fullConfig.sitios[$siteIndex] = $currentSite
    
    $fullConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    
    $script:ConfigCache = $null
}

Export-ModuleMember -Function @(
    'Get-Config',
    'Get-SiteConfig',
    'Get-VpsConfig',
    'Get-CoolifyConfig',
    'Get-Credential',
    'Get-DbPassword',
    'Get-AllSites',
    'Add-Site',
    'Remove-Site',
    'Set-SiteConfig',
    'Get-ConfigFilePath'
)
