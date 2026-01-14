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
    #>
    try {
        $sitio = Test-SiteExists -SiteName $Name
    }
    catch {
        Write-Host "Sitio '$Name' no encontrado en la configuracion" -ForegroundColor Red
        return
    }
    
    $stackName = "$Name-stack"
    
    Write-Host "Procesando: $Name" -ForegroundColor Yellow
    Write-Log -Level "INFO" -Message "Iniciando reinicio de sitio: $Name" -Source "restart-site"
    
    # Intento 1: Usar API de Coolify (Redeploy completo) - Preferido
    if ($sitio.stackUuid -and -not $OnlyDb -and -not $OnlyWordPress) {
        Write-Host "  Metodo: API Coolify (Redeploy/Restart)" -ForegroundColor White
        try {
            Write-Host "  Enviando solicitud de reinicio a Coolify..." -ForegroundColor Cyan
            $result = Restart-CoolifyService -Uuid $sitio.stackUuid
            Write-Host "  Solicitud enviada exitosamente." -ForegroundColor Green
            Write-Log -Level "INFO" -Message "Reiniciado via API Coolify: $Name ($($sitio.stackUuid))" -Source "restart-site"
            
            Write-Host "  NOTA: El proceso puede tardar unos segundos en completarse en el servidor." -ForegroundColor Gray
            return
        }
        catch {
            Write-Host "  Error al reiniciar via API: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Intentando metodo alternativo (Docker restart directo)..." -ForegroundColor Yellow
            Write-Log -Level "WARN" -Message "Fallo reinicio via API, intentando Docker directo: $($_.Exception.Message)" -Source "restart-site"
        }
    }
    
    # Intento 2: Reinicio directo de contenedores Docker (Fallback o especifico)
    Write-Host "  Metodo: Docker Restart (SSH)" -ForegroundColor White
    
    if (-not $OnlyDb) {
        # Intentamos obtener ID por StackName y UUID para mayor precision
        $wpId = Get-WordPressContainerId -StackName $stackName -Uuid $sitio.stackUuid
        if ($wpId) {
            Write-Host "  - WordPress ($wpId)..." -ForegroundColor Cyan
            Restart-DockerContainer -ContainerId $wpId | Out-Null
        }
        else {
            Write-Host "  - WordPress: Contenedor no encontrado" -ForegroundColor DarkGray
        }
    }
    
    if (-not $OnlyWordPress) {
        # Para base de datos, solemos depender del nombre del stack pues no tenemos UUID especifico de servicio DB guardado (es parte del stack)
        $dbId = Get-MariaDbContainerId -StackName $stackName
        if ($dbId) {
            Write-Host "  - MariaDB ($dbId)..." -ForegroundColor Cyan
            Restart-DockerContainer -ContainerId $dbId | Out-Null
        }
        else {
            Write-Host "  - MariaDB: Contenedor no encontrado" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "  OK!" -ForegroundColor Green
    Write-Log -Level "INFO" -Message "Sitio reiniciado (Docker): $Name" -Source "restart-site"
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
