<#
.SYNOPSIS
    Coolify Manager - Herramienta de gestion de sitios WordPress.
.DESCRIPTION
    Punto de entrada principal para gestionar sitios WordPress en Coolify.
    Diseñado para uso manual o por IA.
    
    Esta herramienta permite:
    - Crear nuevos sitios WordPress
    - Listar y monitorear sitios existentes
    - Reiniciar contenedores
    - Desplegar/actualizar el tema Glory
    - Importar bases de datos
    - Ejecutar comandos en contenedores
    - Ver logs
.PARAMETER Action
    Accion a ejecutar: new, list, restart, deploy, import, exec, logs, help
.EXAMPLE
    .\manager.ps1 help
.EXAMPLE
    .\manager.ps1 list
.EXAMPLE
    .\manager.ps1 new -SiteName "blog" -Domain "https://blog.wandori.us"
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("new", "list", "restart", "deploy", "import", "exec", "logs", "help", "status", "set-domain", "redeploy", "debug", "cache", "git-status")]
    [string]$Action = "help",
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$CommandsPath = Join-Path $PSScriptRoot "commands"

function Show-Help {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                       ║" -ForegroundColor Cyan
    Write-Host "  ║   COOLIFY MANAGER - WordPress Management Tool         ║" -ForegroundColor Cyan
    Write-Host "  ║                                                       ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  COMANDOS DISPONIBLES:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    new      " -ForegroundColor Green -NoNewline
    Write-Host "Crear un nuevo sitio WordPress"
    Write-Host "             Ejemplo: .\manager.ps1 new -SiteName blog -Domain https://blog.com"
    Write-Host ""
    Write-Host "    list     " -ForegroundColor Green -NoNewline
    Write-Host "Listar todos los sitios y su estado"
    Write-Host "             Ejemplo: .\manager.ps1 list"
    Write-Host ""
    Write-Host "    restart  " -ForegroundColor Green -NoNewline
    Write-Host "Reiniciar un sitio o todos"
    Write-Host "             Ejemplo: .\manager.ps1 restart -SiteName padel"
    Write-Host "             Ejemplo: .\manager.ps1 restart -All"
    Write-Host ""
    Write-Host "    deploy   " -ForegroundColor Green -NoNewline
    Write-Host "Instalar/actualizar tema Glory"
    Write-Host "             Ejemplo: .\manager.ps1 deploy -SiteName nakomi -Update"
    Write-Host ""
    Write-Host "    import   " -ForegroundColor Green -NoNewline
    Write-Host "Importar base de datos SQL"
    Write-Host "             Ejemplo: .\manager.ps1 import -SiteName padel -SqlFile backup.sql"
    Write-Host ""
    Write-Host "    exec     " -ForegroundColor Green -NoNewline
    Write-Host "Ejecutar comando en contenedor"
    Write-Host "             Ejemplo: .\manager.ps1 exec -SiteName padel -Command 'ls -la'"
    Write-Host ""
    Write-Host "    logs     " -ForegroundColor Green -NoNewline
    Write-Host "Ver logs de un sitio"
    Write-Host "             Ejemplo: .\manager.ps1 logs -SiteName nakomi -Lines 100"
    Write-Host "             Ejemplo: .\manager.ps1 logs -SiteName nakomi -WpDebug -Filter 'error'"
    Write-Host ""
    Write-Host "    debug    " -ForegroundColor Green -NoNewline
    Write-Host "Gestionar modo debug de WordPress"
    Write-Host "             Ejemplo: .\manager.ps1 debug -SiteName padel -Enable"
    Write-Host "             Ejemplo: .\manager.ps1 debug -SiteName padel -Disable"
    Write-Host ""
    Write-Host "    cache    " -ForegroundColor Green -NoNewline
    Write-Host "Gestionar cache headers HTTP"
    Write-Host "             Ejemplo: .\manager.ps1 cache -SiteName padel -Status"
    Write-Host "             Ejemplo: .\manager.ps1 cache -SiteName padel -Enable"
    Write-Host "             Ejemplo: .\manager.ps1 cache -All -Enable"
    Write-Host ""
    Write-Host "    set-domain" -ForegroundColor Green -NoNewline
    Write-Host "Cambiar dominio de un sitio"
    Write-Host "             Ejemplo: .\manager.ps1 set-domain -SiteName padel -Domain https://nuevo.com"
    Write-Host ""
    Write-Host "    status   " -ForegroundColor Green -NoNewline
    Write-Host "Estado rapido del VPS y Coolify"
    Write-Host ""
    Write-Host "    git-status" -ForegroundColor Green -NoNewline
    Write-Host "Diagnostico Git del tema remoto"
    Write-Host "             Ejemplo: .\manager.ps1 git-status -SiteName guillermo"
    Write-Host ""
    Write-Host "    help     " -ForegroundColor Green -NoNewline
    Write-Host "Mostrar esta ayuda"
    Write-Host ""
    Write-Host "  PARA IA:" -ForegroundColor Magenta
    Write-Host "  Cada comando tiene documentacion detallada con Get-Help:"
    Write-Host "    Get-Help $CommandsPath\new-site.ps1 -Full"
    Write-Host ""
    Write-Host "  CONFIGURACION:" -ForegroundColor Yellow
    Write-Host "    Los sitios se guardan en: .agent\coolify-manager\config\settings.json"
    Write-Host ""
}

function Show-QuickStatus {
    $ModulesPath = Join-Path $PSScriptRoot "modules"
    Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
    Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
    
    Write-Host ""
    Write-Host "  ESTADO RAPIDO" -ForegroundColor Cyan
    Write-Host "  =============" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $config = Get-CoolifyConfig
        Write-Host "  VPS: $($config.vps.ip)" -ForegroundColor White
        
        $testSsh = Invoke-SshCommand -Command "echo OK" -Silent
        if ($testSsh -eq "OK") {
            Write-Host "  SSH: " -NoNewline
            Write-Host "Conectado" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  SSH: " -NoNewline
        Write-Host "Error de conexion" -ForegroundColor Red
    }
    
    try {
        $services = Get-CoolifyServices
        Write-Host "  Coolify API: " -NoNewline
        Write-Host "OK" -ForegroundColor Green
        Write-Host "  Servicios: $($services.Count)" -ForegroundColor White
    }
    catch {
        Write-Host "  Coolify API: " -NoNewline
        Write-Host "Error" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Función para invocar un script con argumentos correctamente
function Invoke-CommandScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    
    if ($Arguments -and $Arguments.Count -gt 0) {
        # Reconstruir los argumentos como string para permitir parametros nombrados (-Param Valor)
        # Array splatting (@Args) trata todo como posicional, lo cual rompe los parametros nombrados
        $argString = $Arguments -join ' '
        $fullCommand = "& '$ScriptPath' $argString"
        Invoke-Expression $fullCommand
    }
    else {
        & $ScriptPath
    }
}

switch ($Action) {
    "help" {
        Show-Help
    }
    "status" {
        Show-QuickStatus
    }
    "new" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\new-site.ps1" -Arguments $RemainingArgs
    }
    "list" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\list-sites.ps1" -Arguments $RemainingArgs
    }
    "restart" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\restart-site.ps1" -Arguments $RemainingArgs
    }
    "deploy" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\deploy-theme.ps1" -Arguments $RemainingArgs
    }
    "import" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\import-database.ps1" -Arguments $RemainingArgs
    }
    "exec" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\exec-command.ps1" -Arguments $RemainingArgs
    }
    "logs" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\view-logs.ps1" -Arguments $RemainingArgs
    }
    "set-domain" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\set-domain.ps1" -Arguments $RemainingArgs
    }
    "redeploy" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\redeploy-service.ps1" -Arguments $RemainingArgs
    }
    "debug" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\debug-site.ps1" -Arguments $RemainingArgs
    }
    "cache" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\cache-site.ps1" -Arguments $RemainingArgs
    }
    "git-status" {
        Invoke-CommandScript -ScriptPath "$CommandsPath\git-status.ps1" -Arguments $RemainingArgs
    }
    default {
        Show-Help
    }
}
