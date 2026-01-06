<#
.SYNOPSIS
    Modulo de validacion de inputs y estados.
.DESCRIPTION
    Funciones para validar entradas de usuario, verificar conexiones
    y asegurar que los datos requeridos estan disponibles.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-ConfigPath {
    <#
    .SYNOPSIS
        Obtiene la ruta al archivo de configuracion
    #>
    return Join-Path $script:ModuleRoot "config\settings.json"
}

function Get-ConfigData {
    <#
    .SYNOPSIS
        Obtiene la configuracion completa del sistema
    #>
    $configPath = Get-ConfigPath
    if (-not (Test-Path $configPath)) {
        throw "Archivo de configuracion no encontrado: $configPath"
    }
    return Get-Content $configPath -Raw | ConvertFrom-Json
}

function Test-SiteExists {
    <#
    .SYNOPSIS
        Verifica si un sitio existe en la configuracion
    .PARAMETER SiteName
        Nombre del sitio a buscar
    .OUTPUTS
        Objeto del sitio si existe, lanza excepcion si no
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $config = Get-ConfigData
    $site = $config.sitios | Where-Object { $_.nombre -eq $SiteName }
    
    if (-not $site) {
        $disponibles = ($config.sitios | ForEach-Object { $_.nombre }) -join ", "
        throw "Sitio '$SiteName' no encontrado. Sitios disponibles: $disponibles"
    }
    
    return $site
}

function Test-DomainFormat {
    <#
    .SYNOPSIS
        Valida el formato de un dominio
    .PARAMETER Domain
        Dominio a validar (debe incluir protocolo http/https)
    .OUTPUTS
        $true si es valido, lanza excepcion si no
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Domain
    )
    
    $Domain = $Domain.Trim()
    
    if ($Domain -match '\s') {
        throw "El dominio no puede contener espacios: '$Domain'"
    }
    
    if ($Domain -notmatch '^https?://') {
        throw "El dominio debe comenzar con http:// o https://. Recibido: '$Domain'"
    }
    
    if ($Domain -match '^https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
        Write-Warning "El dominio parece ser una IP. Asegurate de que esto es intencional."
    }
    
    return $true
}

function Test-StackUuidExists {
    <#
    .SYNOPSIS
        Verifica si un sitio tiene UUID de stack configurado
    .PARAMETER SiteName
        Nombre del sitio
    .OUTPUTS
        $true si tiene UUID, $false si no
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName
    )
    
    $site = Test-SiteExists -SiteName $SiteName
    
    if ([string]::IsNullOrWhiteSpace($site.stackUuid)) {
        return $false
    }
    
    return $true
}

function Test-SshConnection {
    <#
    .SYNOPSIS
        Verifica la conexion SSH al VPS
    .OUTPUTS
        $true si la conexion es exitosa, $false si no
    #>
    $config = Get-ConfigData
    $vps = $config.vps
    
    try {
        $result = ssh "$($vps.user)@$($vps.ip)" "echo 'OK'" 2>&1
        if ($result -match 'OK') {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-CoolifyApiConnection {
    <#
    .SYNOPSIS
        Verifica la conexion a la API de Coolify
    .OUTPUTS
        $true si la API responde, $false si no
    #>
    $config = Get-ConfigData
    
    try {
        $headers = @{
            "Authorization" = "Bearer $($config.coolify.apiToken)"
            "Accept"        = "application/json"
        }
        
        $uri = "$($config.coolify.baseUrl)/api/v1/servers"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 10
        
        return $true
    }
    catch {
        return $false
    }
}

function Test-SqlFileExists {
    <#
    .SYNOPSIS
        Verifica que un archivo SQL exista
    .PARAMETER FilePath
        Ruta al archivo SQL
    .OUTPUTS
        $true si existe, lanza excepcion si no
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "Archivo SQL no encontrado: $FilePath"
    }
    
    if (-not $FilePath.EndsWith('.sql')) {
        Write-Warning "El archivo no tiene extension .sql: $FilePath"
    }
    
    return $true
}

function Assert-SiteReady {
    <#
    .SYNOPSIS
        Verifica que un sitio este listo para operaciones
    .PARAMETER SiteName
        Nombre del sitio
    .PARAMETER RequireUuid
        Si se requiere que el sitio tenga UUID
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName,
        
        [switch]$RequireUuid
    )
    
    $site = Test-SiteExists -SiteName $SiteName
    
    if ($RequireUuid -and -not (Test-StackUuidExists -SiteName $SiteName)) {
        throw "El sitio '$SiteName' no tiene UUID de stack configurado. No se pueden ejecutar comandos en este sitio."
    }
    
    return $site
}

Export-ModuleMember -Function @(
    'Test-SiteExists',
    'Test-DomainFormat',
    'Test-StackUuidExists',
    'Test-SshConnection',
    'Test-CoolifyApiConnection',
    'Test-SqlFileExists',
    'Assert-SiteReady',
    'Get-ConfigData',
    'Get-ConfigPath'
)
