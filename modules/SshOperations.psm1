<#
.SYNOPSIS
    Modulo de operaciones SSH para el VPS.
.DESCRIPTION
    Funciones para ejecutar comandos en el VPS y contenedores Docker via SSH.
#>

$script:ModuleRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $ModuleRoot "config\settings.json"

function Get-VpsConfig {
    <#
    .SYNOPSIS
        Carga la configuracion del VPS desde settings.json
    #>
    $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
    return $config.vps
}

function Invoke-SshCommand {
    <#
    .SYNOPSIS
        Ejecuta un comando SSH en el VPS
    .PARAMETER Command
        Comando a ejecutar
    .PARAMETER Silent
        Si es true, no muestra output en consola
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        
        [switch]$Silent
    )
    
    $vps = Get-VpsConfig
    $sshTarget = "$($vps.user)@$($vps.ip)"
    
    if (-not $Silent) {
        Write-Host "Ejecutando en VPS: $Command" -ForegroundColor DarkGray
    }
    
    $result = ssh $sshTarget $Command 2>&1
    return $result
}

function Get-DockerContainers {
    <#
    .SYNOPSIS
        Lista todos los contenedores Docker en el VPS
    .PARAMETER Filter
        Filtro opcional (ej: "name=wordpress")
    #>
    param(
        [string]$Filter = $null
    )
    
    $cmd = "docker ps --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'"
    if ($Filter) {
        $cmd = "docker ps -f '$Filter' --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'"
    }
    
    $output = Invoke-SshCommand -Command $cmd -Silent
    $containers = @()
    
    foreach ($line in $output -split "`n") {
        if ($line.Trim()) {
            $parts = $line -split "`t"
            if ($parts.Count -ge 4) {
                $containers += [PSCustomObject]@{
                    Id = $parts[0]
                    Name = $parts[1]
                    Status = $parts[2]
                    Image = $parts[3]
                }
            }
        }
    }
    
    return $containers
}

function Get-WordPressContainerId {
    <#
    .SYNOPSIS
        Obtiene el ID del contenedor WordPress de un stack especifico
    .PARAMETER StackName
        Nombre del stack (ej: "padel-stack")
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName
    )
    
    $cmd = "docker ps -q -f name=$StackName -f name=wordpress | head -n 1"
    $containerId = Invoke-SshCommand -Command $cmd -Silent
    return $containerId.Trim()
}

function Get-MariaDbContainerId {
    <#
    .SYNOPSIS
        Obtiene el ID del contenedor MariaDB de un stack especifico
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName
    )
    
    $cmd = "docker ps -q -f name=$StackName -f name=mariadb | head -n 1"
    $containerId = Invoke-SshCommand -Command $cmd -Silent
    return $containerId.Trim()
}

function Invoke-DockerExec {
    <#
    .SYNOPSIS
        Ejecuta un comando dentro de un contenedor Docker
    .PARAMETER ContainerId
        ID del contenedor
    .PARAMETER Command
        Comando a ejecutar dentro del contenedor
    .PARAMETER User
        Usuario con el que ejecutar (default: root)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [string]$User = "root"
    )
    
    $dockerCmd = "docker exec -u $User $ContainerId bash -c '$Command'"
    return Invoke-SshCommand -Command $dockerCmd
}

function Copy-FileToContainer {
    <#
    .SYNOPSIS
        Copia un archivo local al contenedor via VPS
    .PARAMETER LocalPath
        Ruta local del archivo
    .PARAMETER ContainerId
        ID del contenedor destino
    .PARAMETER ContainerPath
        Ruta destino dentro del contenedor
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalPath,
        
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [Parameter(Mandatory)]
        [string]$ContainerPath
    )
    
    $vps = Get-VpsConfig
    $sshTarget = "$($vps.user)@$($vps.ip)"
    $tempPath = "/tmp/$(Split-Path -Leaf $LocalPath)"
    
    Write-Host "Copiando archivo al VPS..." -ForegroundColor Cyan
    scp $LocalPath "${sshTarget}:${tempPath}"
    
    Write-Host "Copiando al contenedor..." -ForegroundColor Cyan
    Invoke-SshCommand -Command "docker cp $tempPath ${ContainerId}:${ContainerPath}"
    
    Write-Host "Limpiando temporal..." -ForegroundColor Cyan
    Invoke-SshCommand -Command "rm $tempPath" -Silent
}

function Restart-DockerContainer {
    <#
    .SYNOPSIS
        Reinicia un contenedor Docker
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId
    )
    
    return Invoke-SshCommand -Command "docker restart $ContainerId"
}

function Get-ContainerLogs {
    <#
    .SYNOPSIS
        Obtiene los logs de un contenedor
    .PARAMETER ContainerId
        ID del contenedor
    .PARAMETER Lines
        Numero de lineas a mostrar (default: 50)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerId,
        
        [int]$Lines = 50
    )
    
    return Invoke-SshCommand -Command "docker logs --tail $Lines $ContainerId"
}

Export-ModuleMember -Function @(
    'Get-VpsConfig',
    'Invoke-SshCommand',
    'Get-DockerContainers',
    'Get-WordPressContainerId',
    'Get-MariaDbContainerId',
    'Invoke-DockerExec',
    'Copy-FileToContainer',
    'Restart-DockerContainer',
    'Get-ContainerLogs'
)
