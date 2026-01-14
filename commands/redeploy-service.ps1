<#
.SYNOPSIS
    Fuerza un despliegue (deploy) de un sitio via API Coolify.
.DESCRIPTION
    Util para aplicar cambios de configuracion (como dominios) que requieren
    regeneracion de proxy/traefik.
.PARAMETER SiteName
    Nombre del sitio
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DESPLIEGUE DE SERVICIO (API)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Iniciando despliegue forzado: $SiteName" -Source "redeploy"
    
    Write-Host "Sitio: $SiteName" -ForegroundColor White
    Write-Host "UUID:  $($sitio.stackUuid)" -ForegroundColor Gray
    
    Write-Host "Enviando solicitud de despliegue a Coolify..." -ForegroundColor Yellow
    $result = Deploy-CoolifyService -Uuid $sitio.stackUuid
    
    Write-Host "Solicitud enviada exitosamente!" -ForegroundColor Green
    Write-Host "Coolify comenzara a reconstruir/desplegar el stack en breve." -ForegroundColor Gray
    Write-Log -Level "INFO" -Message "Despliegue solicitado: $SiteName" -Source "redeploy"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log -Level "ERROR" -Message "Error en despliegue: $($_.Exception.Message)" -Source "redeploy"
    exit 1
}

Write-Host ""
