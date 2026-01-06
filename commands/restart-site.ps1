<#
.SYNOPSIS
    Reinicia un sitio WordPress en Coolify.
.DESCRIPTION
    Reinicia los contenedores de un sitio especifico.
    Puede reiniciar solo WordPress, solo MariaDB o ambos.
.PARAMETER SiteName
    Nombre del sitio a reiniciar
.PARAMETER All
    Reinicia todos los sitios
.PARAMETER OnlyDb
    Solo reinicia el contenedor de base de datos
.PARAMETER OnlyWordPress
    Solo reinicia el contenedor de WordPress
.EXAMPLE
    .\restart-site.ps1 -SiteName "padel"
.EXAMPLE
    .\restart-site.ps1 -All
#>

param(
    [Parameter(ParameterSetName = "Single")]
    [string]$SiteName,
    
    [Parameter(ParameterSetName = "All")]
    [switch]$All,
    
    [switch]$OnlyDb,
    
    [switch]$OnlyWordPress
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

function Restart-SingleSite {
    param([string]$Name)
    
    <#
    Validacion: Verificar que el sitio existe
    Nota: No requerimos UUID aqui porque podemos reiniciar desde la config
    #>
    try {
        $sitio = Test-SiteExists -SiteName $Name
    }
    catch {
        Write-Host "Sitio '$Name' no encontrado en la configuracion" -ForegroundColor Red
        return
    }
    
    $stackName = "$Name-stack"
    
    Write-Host "Reiniciando: $Name" -ForegroundColor Yellow
    Write-Log -Level "INFO" -Message "Reiniciando sitio: $Name" -Source "restart-site"
    
    if (-not $OnlyDb) {
        $wpId = Get-WordPressContainerId -StackName $stackName
        if ($wpId) {
            Write-Host "  - WordPress..." -ForegroundColor Cyan
            Restart-DockerContainer -ContainerId $wpId | Out-Null
        }
    }
    
    if (-not $OnlyWordPress) {
        $dbId = Get-MariaDbContainerId -StackName $stackName
        if ($dbId) {
            Write-Host "  - MariaDB..." -ForegroundColor Cyan
            Restart-DockerContainer -ContainerId $dbId | Out-Null
        }
    }
    
    Write-Host "  OK!" -ForegroundColor Green
    Write-Log -Level "INFO" -Message "Sitio reiniciado: $Name" -Source "restart-site"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REINICIO DE SITIOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($All) {
    $config = Get-CoolifyConfig
    foreach ($sitio in $config.sitios) {
        Restart-SingleSite -Name $sitio.nombre
    }
}
elseif ($SiteName) {
    Restart-SingleSite -Name $SiteName
}
else {
    Write-Host "Uso: .\restart-site.ps1 -SiteName <nombre>" -ForegroundColor Yellow
    Write-Host "     .\restart-site.ps1 -All" -ForegroundColor Yellow
    Write-Host ""
    
    $config = Get-CoolifyConfig
    Write-Host "Sitios disponibles:" -ForegroundColor Cyan
    foreach ($sitio in $config.sitios) {
        Write-Host "  - $($sitio.nombre)" -ForegroundColor White
    }
}

Write-Host ""
