<#
.SYNOPSIS
    Modulo de API para Coolify v4.
.DESCRIPTION
    Funciones para interactuar con la API REST de Coolify.
    Permite crear, listar, reiniciar y gestionar servicios.
#>

$script:ModuleRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $ModuleRoot "config\settings.json"

function Get-CoolifyConfig {
    <#
    .SYNOPSIS
        Carga la configuracion de Coolify desde settings.json
    #>
    if (-not (Test-Path $script:ConfigPath)) {
        throw "Archivo de configuracion no encontrado: $script:ConfigPath"
    }
    return Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
}

function Get-CoolifyHeaders {
    <#
    .SYNOPSIS
        Retorna los headers necesarios para la API de Coolify
    #>
    $config = Get-CoolifyConfig
    return @{
        "Authorization" = "Bearer $($config.coolify.apiToken)"
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }
}

function Invoke-CoolifyApi {
    <#
    .SYNOPSIS
        Ejecuta una peticion a la API de Coolify
    .PARAMETER Endpoint
        Endpoint de la API (sin la base URL)
    .PARAMETER Method
        Metodo HTTP (GET, POST, DELETE, etc)
    .PARAMETER Body
        Cuerpo de la peticion (sera convertido a JSON)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [ValidateSet("GET", "POST", "DELETE", "PATCH", "PUT")]
        [string]$Method = "GET",
        
        [object]$Body = $null
    )
    
    $config = Get-CoolifyConfig
    $url = "$($config.coolify.baseUrl)/api/v1$Endpoint"
    $headers = Get-CoolifyHeaders
    
    $params = @{
        Uri = $url
        Method = $Method
        Headers = $headers
        ContentType = "application/json"
    }
    
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    
    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Error "Error en API Coolify: $($_.Exception.Message)"
        Write-Error "URL: $url"
        throw
    }
}

function Get-CoolifyServers {
    <#
    .SYNOPSIS
        Lista todos los servidores registrados en Coolify
    #>
    return Invoke-CoolifyApi -Endpoint "/servers"
}

function Get-CoolifyProjects {
    <#
    .SYNOPSIS
        Lista todos los proyectos en Coolify
    #>
    return Invoke-CoolifyApi -Endpoint "/projects"
}

function Get-CoolifyServices {
    <#
    .SYNOPSIS
        Lista todos los servicios (stacks) en Coolify
    #>
    return Invoke-CoolifyApi -Endpoint "/services"
}

function Get-CoolifyServiceByUuid {
    <#
    .SYNOPSIS
        Obtiene un servicio especifico por su UUID
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uuid
    )
    return Invoke-CoolifyApi -Endpoint "/services/$Uuid"
}

function New-CoolifyWordPressStack {
    <#
    .SYNOPSIS
        Crea un nuevo stack WordPress + MariaDB en Coolify
    .PARAMETER SiteName
        Nombre del sitio (se usara como prefijo del stack)
    .PARAMETER Domain
        Dominio completo (ej: https://mi-sitio.com)
    .PARAMETER DbPassword
        Contrasena para el usuario de BD (se genera si no se proporciona)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SiteName,
        
        [Parameter(Mandatory)]
        [string]$Domain,
        
        [string]$DbPassword = $null
    )
    
    $config = Get-CoolifyConfig
    
    if (-not $DbPassword) {
        $DbPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    }
    $RootPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
    
    $templatePath = Join-Path $script:ModuleRoot "templates\wordpress-stack.yaml"
    $yaml = Get-Content $templatePath -Raw
    $yaml = $yaml -replace '\{\{DB_PASSWORD\}\}', $DbPassword
    $yaml = $yaml -replace '\{\{ROOT_PASSWORD\}\}', $RootPassword
    $yaml = $yaml -replace '\{\{DOMAIN\}\}', $Domain
    
    $base64Yaml = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($yaml))
    
    $body = @{
        project_uuid = $config.coolify.projectUuid
        environment_name = $config.coolify.environmentName
        server_uuid = $config.coolify.serverUuid
        docker_compose_raw = $base64Yaml
        name = "$SiteName-stack"
    }
    
    $result = Invoke-CoolifyApi -Endpoint "/services" -Method POST -Body $body
    
    Write-Host "Stack creado exitosamente!" -ForegroundColor Green
    Write-Host "UUID: $($result.uuid)" -ForegroundColor Cyan
    Write-Host "DB Password: $DbPassword" -ForegroundColor Yellow
    Write-Host "Root Password: $RootPassword" -ForegroundColor Yellow
    
    return @{
        uuid = $result.uuid
        dbPassword = $DbPassword
        rootPassword = $RootPassword
    }
}

function Start-CoolifyService {
    <#
    .SYNOPSIS
        Inicia/Despliega un servicio en Coolify
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uuid
    )
    return Invoke-CoolifyApi -Endpoint "/services/$Uuid/start" -Method POST
}

function Stop-CoolifyService {
    <#
    .SYNOPSIS
        Detiene un servicio en Coolify
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uuid
    )
    return Invoke-CoolifyApi -Endpoint "/services/$Uuid/stop" -Method POST
}

function Restart-CoolifyService {
    <#
    .SYNOPSIS
        Reinicia un servicio en Coolify
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uuid
    )
    return Invoke-CoolifyApi -Endpoint "/services/$Uuid/restart" -Method POST
}

Export-ModuleMember -Function @(
    'Get-CoolifyConfig',
    'Invoke-CoolifyApi',
    'Get-CoolifyServers',
    'Get-CoolifyProjects', 
    'Get-CoolifyServices',
    'Get-CoolifyServiceByUuid',
    'New-CoolifyWordPressStack',
    'Start-CoolifyService',
    'Stop-CoolifyService',
    'Restart-CoolifyService'
)
