<#
.SYNOPSIS
    Lista todos los sitios WordPress registrados y su estado.
.DESCRIPTION
    Muestra una tabla con todos los sitios configurados y su estado
    actual en Coolify (corriendo, detenido, etc.)
.PARAMETER Detailed
    Muestra informacion adicional de cada sitio
.EXAMPLE
    .\list-sites.ps1
.EXAMPLE
    .\list-sites.ps1 -Detailed
#>

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Log -Level "DEBUG" -Message "Listando sitios" -Source "list-sites"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SITIOS WORDPRESS EN COOLIFY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$config = Get-CoolifyConfig
$containers = Get-DockerContainers

Write-Host "Sitios registrados localmente:" -ForegroundColor Yellow
Write-Host ""

$tableData = @()

foreach ($sitio in $config.sitios) {
    $wpContainer = $containers | Where-Object { 
        $_.Name -like "*$($sitio.nombre)*" -and $_.Name -like "*wordpress*" 
    }
    
    $status = if ($wpContainer) { 
        if ($wpContainer.Status -like "*Up*") { "OK" } else { "DOWN" }
    }
    else { 
        "N/A" 
    }
    
    $statusColor = switch ($status) {
        "OK" { "Green" }
        "DOWN" { "Red" }
        default { "Yellow" }
    }
    
    $tableData += [PSCustomObject]@{
        Nombre      = $sitio.nombre
        Dominio     = $sitio.dominio
        Estado      = $status
        GloryBranch = $sitio.gloryBranch
        StackUuid   = if ($sitio.stackUuid) { $sitio.stackUuid.Substring(0, 8) + "..." } else { "-" }
    }
    
    Write-Host "  $($sitio.nombre.PadRight(15))" -NoNewline
    Write-Host "[$status]".PadRight(8) -ForegroundColor $statusColor -NoNewline
    Write-Host " $($sitio.dominio)" -ForegroundColor White
}

Write-Host ""

if ($Detailed) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  CONTENEDORES DOCKER ACTIVOS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $containers | Format-Table -AutoSize
}

Write-Host ""
Write-Host "Total de sitios: $($config.sitios.Count)" -ForegroundColor DarkGray
Write-Host ""
