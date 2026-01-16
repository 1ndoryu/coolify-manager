<#
.SYNOPSIS
    Gestiona cache headers HTTP para sitios WordPress.
.DESCRIPTION
    Permite habilitar, deshabilitar o ver el estado de los cache headers
    en archivos .htaccess de sitios WordPress desplegados en Coolify.
    
    Los cache headers mejoran significativamente el rendimiento del sitio
    al indicar a los navegadores que pueden cachear archivos estaticos
    (CSS, JS, imagenes, fuentes) por periodos prolongados.
.PARAMETER SiteName
    Nombre del sitio (requerido si no se usa -All)
.PARAMETER Enable
    Habilita cache headers agregando reglas al .htaccess
.PARAMETER Disable
    Deshabilita cache headers removiendo las reglas del .htaccess
.PARAMETER Status
    Muestra el estado actual de cache headers (default si no se especifica accion)
.PARAMETER All
    Aplica la operacion a todos los sitios configurados
.EXAMPLE
    .\cache-site.ps1 -SiteName "padel" -Status
    Muestra el estado de cache headers para el sitio padel
.EXAMPLE
    .\cache-site.ps1 -SiteName "padel" -Enable
    Habilita cache headers para el sitio padel
.EXAMPLE
    .\cache-site.ps1 -SiteName "padel" -Disable
    Deshabilita cache headers para el sitio padel
.EXAMPLE
    .\cache-site.ps1 -All -Enable
    Habilita cache headers en todos los sitios
.EXAMPLE
    .\cache-site.ps1 -All -Status
    Muestra el estado de cache en todos los sitios
#>

param(
    [string]$SiteName,
    
    [switch]$Enable,
    
    [switch]$Disable,
    
    [switch]$Status,
    
    [switch]$All
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPress\CacheManager.psm1") -Force

<#
Validacion de parametros
#>
if (-not $All -and -not $SiteName) {
    Write-Host ""
    Write-Host "ERROR: Debe especificar -SiteName o usar -All" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ejemplos:" -ForegroundColor Yellow
    Write-Host "  .\manager.ps1 cache -SiteName padel -Status"
    Write-Host "  .\manager.ps1 cache -SiteName padel -Enable"
    Write-Host "  .\manager.ps1 cache -All -Status"
    Write-Host ""
    exit 1
}

<#
Si no se especifica ninguna accion, mostrar status
#>
if (-not $Enable -and -not $Disable) {
    $Status = $true
}

<#
Obtener configuracion VPS
#>
$vps = Get-VpsConfig
$sshTarget = "$($vps.user)@$($vps.ip)"

<#
Funcion auxiliar para procesar un solo sitio
#>
function Process-Site {
    param(
        [string]$SiteName,
        [bool]$ShowStatus,
        [bool]$DoEnable,
        [bool]$DoDisable
    )
    
    # Validar sitio
    try {
        $siteConfig = Assert-SiteReady -SiteName $SiteName -RequireUuid
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Obtener container ID
    $containerId = Get-WordPressContainerId -Uuid $siteConfig.stackUuid
    if (-not $containerId) {
        Write-Host "  No se encontro contenedor WordPress" -ForegroundColor Red
        return $false
    }
    
    # Status
    if ($ShowStatus -and -not $DoEnable -and -not $DoDisable) {
        $status = Get-CacheStatus -ContainerId $containerId -SshTarget $sshTarget
        
        Write-Host "  .htaccess: " -NoNewline
        if ($status.HtaccessExists) {
            Write-Host "Existe" -ForegroundColor Green
        }
        else {
            Write-Host "No existe" -ForegroundColor Yellow
        }
        
        Write-Host "  Cache: " -NoNewline
        if ($status.CacheEnabled) {
            Write-Host "HABILITADO" -ForegroundColor Green
        }
        else {
            Write-Host "NO CONFIGURADO" -ForegroundColor Yellow
        }
        
        if ($status.ModulesCount -ne $null) {
            Write-Host "  Modulos Apache: " -NoNewline
            if ($status.ModulesCount -ge 2) {
                Write-Host "OK (expires + headers)" -ForegroundColor Green
            }
            elseif ($status.ModulesCount -eq 1) {
                Write-Host "Parcial" -ForegroundColor Yellow
            }
            else {
                Write-Host "No cargados" -ForegroundColor Red
            }
        }
        
        return $true
    }
    
    # Enable
    if ($DoEnable) {
        Write-Host "  Verificando modulos Apache..." -ForegroundColor DarkGray
        $moduleStatus = Test-ApacheModules -ContainerId $containerId -SshTarget $sshTarget
        
        Write-Host "  Habilitando cache headers..." -ForegroundColor DarkGray
        $result = Enable-CacheHeaders -ContainerId $containerId -SshTarget $sshTarget
        
        if ($result -match "SUCCESS") {
            Write-Host "  Cache: " -NoNewline
            Write-Host "HABILITADO" -ForegroundColor Green
            return $true
        }
        elseif ($result -match "ALREADY_CONFIGURED") {
            Write-Host "  Cache: " -NoNewline
            Write-Host "Ya estaba habilitado" -ForegroundColor Cyan
            return $true
        }
        else {
            Write-Host "  Error: $result" -ForegroundColor Red
            return $false
        }
    }
    
    # Disable
    if ($DoDisable) {
        Write-Host "  Deshabilitando cache headers..." -ForegroundColor DarkGray
        $result = Disable-CacheHeaders -ContainerId $containerId -SshTarget $sshTarget
        
        if ($result -match "SUCCESS") {
            Write-Host "  Cache: " -NoNewline
            Write-Host "DESHABILITADO" -ForegroundColor Yellow
            return $true
        }
        elseif ($result -match "NOT_CONFIGURED") {
            Write-Host "  Cache: " -NoNewline
            Write-Host "No estaba configurado" -ForegroundColor Cyan
            return $true
        }
        elseif ($result -match "NOT_EXISTS") {
            Write-Host "  Cache: " -NoNewline
            Write-Host "El .htaccess no existe" -ForegroundColor Yellow
            return $true
        }
        else {
            Write-Host "  Error: $result" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

<#
Procesar todos los sitios
#>
if ($All) {
    $config = Get-ConfigData
    $sites = $config.sitios | Where-Object { -not [string]::IsNullOrWhiteSpace($_.stackUuid) }
    
    if (-not $sites -or $sites.Count -eq 0) {
        Write-Host ""
        Write-Host "No hay sitios configurados con UUID." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
    
    Write-Host ""
    if ($Enable) {
        Write-Host "Habilitando cache headers en todos los sitios..." -ForegroundColor Cyan
    }
    elseif ($Disable) {
        Write-Host "Deshabilitando cache headers en todos los sitios..." -ForegroundColor Cyan
    }
    else {
        Write-Host "Estado de cache headers - Todos los sitios" -ForegroundColor Cyan
    }
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    
    foreach ($site in $sites) {
        Write-Host "[$($site.nombre)]" -ForegroundColor White
        $result = Process-Site -SiteName $site.nombre -ShowStatus $Status -DoEnable $Enable -DoDisable $Disable
        if ($result) {
            $successCount++
        }
        else {
            $failCount++
        }
        Write-Host ""
    }
    
    # Resumen
    Write-Host "------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Completado: $successCount exitosos" -NoNewline -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host ", $failCount fallidos" -ForegroundColor Red
    }
    else {
        Write-Host ""
    }
    Write-Host ""
    exit 0
}

<#
Procesar un solo sitio
#>
Write-Host ""
if ($Enable) {
    Write-Host "Habilitando cache headers para: $SiteName" -ForegroundColor Cyan
}
elseif ($Disable) {
    Write-Host "Deshabilitando cache headers para: $SiteName" -ForegroundColor Cyan
}
else {
    Write-Host "Estado de cache headers - $SiteName" -ForegroundColor Cyan
}
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$result = Process-Site -SiteName $SiteName -ShowStatus $Status -DoEnable $Enable -DoDisable $Disable

Write-Host ""

if (-not $Enable -and -not $Disable) {
    # Mostrar ayuda adicional solo en modo status
    Write-Host "Comandos disponibles:" -ForegroundColor DarkGray
    Write-Host "  .\manager.ps1 cache -SiteName $SiteName -Enable     # Habilitar cache" -ForegroundColor DarkGray
    Write-Host "  .\manager.ps1 cache -SiteName $SiteName -Disable    # Deshabilitar cache" -ForegroundColor DarkGray
    Write-Host ""
}

exit 0
