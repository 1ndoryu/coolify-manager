<#
.SYNOPSIS
    Gestiona un servidor Minecraft Java en Coolify.
.DESCRIPTION
    Permite crear, reiniciar, ver logs, ejecutar comandos y gestionar
    un servidor Minecraft Java Edition desplegado como stack en Coolify.
    Usa la imagen itzg/minecraft-server (ultima version).

    IMPORTANTE: Este comando NO afecta los stacks WordPress existentes.
    Minecraft se maneja como un tipo de servicio separado.
.PARAMETER Action
    Accion a realizar: new, logs, console, restart, status, remove
.PARAMETER ServerName
    Nombre identificador del servidor Minecraft
.PARAMETER Memory
    RAM asignada al servidor (default: 2G). Formatos: 1G, 2G, 4G, 512M
.PARAMETER MaxPlayers
    Maximo de jugadores simultaneos (default: 20)
.PARAMETER Motd
    Mensaje del dia que aparece en la lista de servidores
.PARAMETER Difficulty
    Dificultad del servidor: peaceful, easy, normal, hard (default: normal)
.PARAMETER Version
    Version de Minecraft (default: LATEST)
.PARAMETER Port
    Puerto externo del servidor (default: 25565)
.EXAMPLE
    .\minecraft-server.ps1 -Action new -ServerName "survival"
.EXAMPLE
    .\minecraft-server.ps1 -Action new -ServerName "creative" -Memory 4G -MaxPlayers 50
.EXAMPLE
    .\minecraft-server.ps1 -Action logs -ServerName "survival"
.EXAMPLE
    .\minecraft-server.ps1 -Action console -ServerName "survival" -ConsoleCommand "op PlayerName"
.EXAMPLE
    .\minecraft-server.ps1 -Action status -ServerName "survival"
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("new", "logs", "console", "restart", "status", "remove")]
    [string]$Action,

    [Parameter(Mandatory)]
    [string]$ServerName,

    [string]$Memory = "2G",
    [int]$MaxPlayers = 20,
    [string]$Motd = "Servidor Minecraft - Coolify Managed",
    [ValidateSet("peaceful", "easy", "normal", "hard")]
    [string]$Difficulty = "normal",
    [string]$Version = "LATEST",
    [int]$Port = 25565,
    [string]$ConsoleCommand,
    [int]$Lines = 100
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

<#
    Busca el contenedor Minecraft por UUID del stack en Coolify.
    Patron de nombre en Coolify v4: minecraft-{UUID}
#>
function Get-MinecraftContainerId {
    param(
        [Parameter(Mandatory)]
        [string]$Uuid
    )

    $cmd = "docker ps -q -f name=minecraft-$Uuid | head -n 1"
    $containerId = (Invoke-SshCommand -Command $cmd -Silent).Trim()

    if (-not $containerId) {
        # Fallback: buscar por imagen itzg/minecraft-server
        $cmd = "docker ps -q -f ancestor=itzg/minecraft-server | head -n 1"
        $containerId = (Invoke-SshCommand -Command $cmd -Silent).Trim()
    }

    return $containerId
}

<#
    Obtiene la configuracion del servidor Minecraft desde settings.json.
    Los servidores Minecraft se almacenan en la clave "minecraft" (array),
    separada de la clave "sitios" de WordPress.
#>
function Get-MinecraftServer {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $configPath = Join-Path $PSScriptRoot "..\config\settings.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    if (-not $config.minecraft) {
        throw "No hay servidores Minecraft configurados. Crea uno con: .\manager.ps1 minecraft -Action new -ServerName `"$Name`""
    }

    $server = $config.minecraft | Where-Object { $_.nombre -eq $Name }
    if (-not $server) {
        $disponibles = ($config.minecraft | ForEach-Object { $_.nombre }) -join ", "
        throw "Servidor Minecraft '$Name' no encontrado. Disponibles: $disponibles"
    }

    return $server
}

switch ($Action) {
    "new" {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  CREACION DE SERVIDOR MINECRAFT JAVA" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Servidor:    $ServerName" -ForegroundColor White
        Write-Host "Version:     $Version" -ForegroundColor White
        Write-Host "Memoria:     $Memory" -ForegroundColor White
        Write-Host "Jugadores:   $MaxPlayers" -ForegroundColor White
        Write-Host "Dificultad:  $Difficulty" -ForegroundColor White
        Write-Host "Puerto:      $Port" -ForegroundColor White
        Write-Host "MOTD:        $Motd" -ForegroundColor White
        Write-Host ""

        # Verificar que no exista un server con el mismo nombre
        $configPath = Join-Path $PSScriptRoot "..\config\settings.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json

        if ($config.minecraft) {
            $existente = $config.minecraft | Where-Object { $_.nombre -eq $ServerName }
            if ($existente) {
                throw "Ya existe un servidor Minecraft con nombre '$ServerName'. UUID: $($existente.stackUuid)"
            }
        }

        Write-Host "[1/3] Creando stack Minecraft en Coolify..." -ForegroundColor Yellow

        # Leer y personalizar el template
        $templatePath = Join-Path $PSScriptRoot "..\templates\minecraft-stack.yaml"
        if (-not (Test-Path $templatePath)) {
            throw "Template Minecraft no encontrado: $templatePath"
        }

        $yaml = Get-Content $templatePath -Raw
        $yaml = $yaml -replace '\{\{SERVER_NAME\}\}', $ServerName

        # Ajustar variables de entorno segun parametros del usuario
        # Las regex usan ['\"] para ser resilientes a ambos formatos de comillas
        $yaml = $yaml -replace "MEMORY: ['\`""]2G['\`""]", "MEMORY: '$Memory'"
        $yaml = $yaml -replace "MAX_PLAYERS: ['\`""]20['\`""]", "MAX_PLAYERS: '$MaxPlayers'"
        $yaml = $yaml -replace "MOTD: ['\`""]Servidor Minecraft - Coolify Managed['\`""]", "MOTD: '$Motd'"
        $yaml = $yaml -replace "DIFFICULTY: ['\`""]normal['\`""]", "DIFFICULTY: '$Difficulty'"
        $yaml = $yaml -replace "VERSION: ['\`""]LATEST['\`""]", "VERSION: '$Version'"

        # Ajustar puerto si es diferente al default
        if ($Port -ne 25565) {
            $yaml = $yaml -replace "['\`""]25565:25565['\`""]", "'${Port}:25565'"
        }

        $base64Yaml = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($yaml))

        $coolifyConfig = Get-CoolifyConfig
        $body = @{
            project_uuid       = $coolifyConfig.coolify.projectUuid
            environment_name   = $coolifyConfig.coolify.environmentName
            server_uuid        = $coolifyConfig.coolify.serverUuid
            docker_compose_raw = $base64Yaml
            name               = "minecraft-$ServerName"
        }

        $result = Invoke-CoolifyApi -Endpoint "/services" -Method POST -Body $body

        Write-Host "Stack creado! UUID: $($result.uuid)" -ForegroundColor Green
        Write-Log -Level "INFO" -Message "Servidor Minecraft creado: $ServerName (UUID: $($result.uuid))" -Source "minecraft"

        Write-Host ""
        Write-Host "[2/3] Desplegando stack..." -ForegroundColor Yellow
        Start-CoolifyService -Uuid $result.uuid

        Write-Host "Esperando 15 segundos para que el contenedor inicie..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 15

        Write-Host ""
        Write-Host "[3/3] Registrando servidor en configuracion..." -ForegroundColor Yellow

        $nuevoServer = @{
            nombre    = $ServerName
            stackUuid = $result.uuid
            version   = $Version
            memory    = $Memory
            port      = $Port
            tipo      = "minecraft-java"
        }

        # Inicializar array minecraft si no existe
        if (-not $config.minecraft) {
            $config | Add-Member -NotePropertyName "minecraft" -NotePropertyValue @() -Force
        }

        $config.minecraft += $nuevoServer
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  SERVIDOR MINECRAFT CREADO!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "UUID: $($result.uuid)" -ForegroundColor Cyan

        $vpsConfig = Get-CoolifyConfig
        $vpsIp = $vpsConfig.vps.ip
        Write-Host "Conectar: $($vpsIp):$Port" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "NOTA: El servidor tardara 1-2 minutos en descargar Minecraft" -ForegroundColor DarkGray
        Write-Host "      y generar el mundo. Usa 'logs' para ver el progreso." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Comandos utiles:" -ForegroundColor White
        Write-Host "  .\manager.ps1 minecraft -Action logs    -ServerName $ServerName" -ForegroundColor Gray
        Write-Host "  .\manager.ps1 minecraft -Action status  -ServerName $ServerName" -ForegroundColor Gray
        Write-Host "  .\manager.ps1 minecraft -Action console -ServerName $ServerName -ConsoleCommand 'op TuNombre'" -ForegroundColor Gray
        Write-Host ""

        Write-Log -Level "INFO" -Message "Servidor Minecraft listo: $ServerName @ $($vpsIp):$Port" -Source "minecraft"
    }

    "logs" {
        $server = Get-MinecraftServer -Name $ServerName
        $containerId = Get-MinecraftContainerId -Uuid $server.stackUuid

        if (-not $containerId) {
            throw "No se encontro el contenedor Minecraft para '$ServerName'. Verifica que el stack esta corriendo."
        }

        Write-Host ""
        Write-Host "  LOGS MINECRAFT: $ServerName" -ForegroundColor Cyan
        Write-Host "  Contenedor: $containerId" -ForegroundColor DarkGray
        Write-Host ""

        $logs = Get-ContainerLogs -ContainerId $containerId -Lines $Lines
        foreach ($line in $logs -split "`n") {
            $trimmed = $line.Trim()
            if (-not $trimmed) { continue }

            if ($trimmed -match 'ERROR|SEVERE|FATAL') {
                Write-Host $trimmed -ForegroundColor Red
            }
            elseif ($trimmed -match 'WARN') {
                Write-Host $trimmed -ForegroundColor Yellow
            }
            elseif ($trimmed -match 'Done.*For help') {
                Write-Host $trimmed -ForegroundColor Green
            }
            elseif ($trimmed -match 'joined|left') {
                Write-Host $trimmed -ForegroundColor Magenta
            }
            else {
                Write-Host $trimmed -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    "console" {
        if (-not $ConsoleCommand) {
            throw "Debes especificar -ConsoleCommand para enviar un comando a la consola de Minecraft. Ejemplo: -ConsoleCommand 'op JugadorX'"
        }

        $server = Get-MinecraftServer -Name $ServerName
        $containerId = Get-MinecraftContainerId -Uuid $server.stackUuid

        if (-not $containerId) {
            throw "No se encontro el contenedor Minecraft para '$ServerName'."
        }

        Write-Host ""
        Write-Host "  CONSOLA MINECRAFT: $ServerName" -ForegroundColor Cyan
        Write-Host "  Comando: $ConsoleCommand" -ForegroundColor White
        Write-Host ""

        # Usar rcon-cli para enviar comandos al server Minecraft
        # La imagen itzg/minecraft-server incluye rcon-cli por defecto
        $escapedCmd = $ConsoleCommand -replace "'", "'\''"
        $dockerCmd = "docker exec $containerId rcon-cli '$escapedCmd'"
        $result = Invoke-SshCommand -Command $dockerCmd

        if ($result) {
            Write-Host "Respuesta:" -ForegroundColor Yellow
            foreach ($line in $result -split "`n") {
                if ($line.Trim()) {
                    Write-Host "  $($line.Trim())" -ForegroundColor White
                }
            }
        }
        else {
            Write-Host "Comando enviado (sin respuesta del servidor)" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Log -Level "INFO" -Message "Comando MC ejecutado en $ServerName`: $ConsoleCommand" -Source "minecraft"
    }

    "restart" {
        $server = Get-MinecraftServer -Name $ServerName

        Write-Host ""
        Write-Host "  REINICIANDO MINECRAFT: $ServerName" -ForegroundColor Yellow
        Write-Host ""

        try {
            Restart-CoolifyService -Uuid $server.stackUuid
            Write-Host "Solicitud de reinicio enviada a Coolify." -ForegroundColor Green
            Write-Host "El servidor tardara ~1 minuto en estar disponible." -ForegroundColor DarkGray
            Write-Log -Level "INFO" -Message "Reinicio solicitado: $ServerName" -Source "minecraft"
        }
        catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message "Error reiniciando $ServerName`: $($_.Exception.Message)" -Source "minecraft"
            exit 1
        }

        Write-Host ""
    }

    "status" {
        $server = Get-MinecraftServer -Name $ServerName
        $containerId = Get-MinecraftContainerId -Uuid $server.stackUuid

        Write-Host ""
        Write-Host "  ESTADO MINECRAFT: $ServerName" -ForegroundColor Cyan
        Write-Host "  =============================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  UUID Stack:  $($server.stackUuid)" -ForegroundColor White
        Write-Host "  Version:     $($server.version)" -ForegroundColor White
        Write-Host "  Memoria:     $($server.memory)" -ForegroundColor White
        Write-Host "  Puerto:      $($server.port)" -ForegroundColor White

        if ($containerId) {
            Write-Host "  Contenedor:  $containerId" -ForegroundColor Green

            # Verificar si el server esta realmente listo via healthcheck
            $healthCmd = "docker inspect --format='{{.State.Health.Status}}' $containerId 2>/dev/null || echo 'unknown'"
            $health = (Invoke-SshCommand -Command $healthCmd -Silent).Trim()

            $statusColor = switch ($health) {
                "healthy"   { "Green" }
                "starting"  { "Yellow" }
                "unhealthy" { "Red" }
                default     { "DarkGray" }
            }
            Write-Host "  Salud:       $health" -ForegroundColor $statusColor

            # Numero de jugadores conectados via rcon-cli
            try {
                $listCmd = "docker exec $containerId rcon-cli list 2>/dev/null"
                $players = (Invoke-SshCommand -Command $listCmd -Silent).Trim()
                if ($players) {
                    Write-Host "  Jugadores:   $players" -ForegroundColor Magenta
                }
            }
            catch {
                Write-Host "  Jugadores:   (rcon no disponible aun)" -ForegroundColor DarkGray
            }

            $vpsConfig = Get-CoolifyConfig
            Write-Host ""
            Write-Host "  Conectar:    $($vpsConfig.vps.ip):$($server.port)" -ForegroundColor Yellow
        }
        else {
            Write-Host "  Contenedor:  NO ENCONTRADO" -ForegroundColor Red
            Write-Host "  El servidor puede estar apagado o en proceso de inicio." -ForegroundColor DarkGray
        }

        Write-Host ""
    }

    "remove" {
        $server = Get-MinecraftServer -Name $ServerName

        Write-Host ""
        Write-Host "  ELIMINANDO SERVIDOR MINECRAFT: $ServerName" -ForegroundColor Red
        Write-Host ""
        Write-Host "  UUID: $($server.stackUuid)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ADVERTENCIA: Esto detendra el servidor y eliminara" -ForegroundColor Yellow
        Write-Host "  la configuracion local. Los datos del mundo se" -ForegroundColor Yellow
        Write-Host "  mantienen en el volumen Docker del VPS." -ForegroundColor Yellow
        Write-Host ""

        try {
            # Detener el servicio en Coolify
            Stop-CoolifyService -Uuid $server.stackUuid
            Write-Host "Servicio detenido en Coolify." -ForegroundColor Green
        }
        catch {
            Write-Host "Advertencia al detener: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Eliminar de settings.json
        $configPath = Join-Path $PSScriptRoot "..\config\settings.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json

        $config.minecraft = @($config.minecraft | Where-Object { $_.nombre -ne $ServerName })

        # Si el array queda vacio, mantenerlo como array vacio
        if ($config.minecraft.Count -eq 0) {
            $config.minecraft = @()
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

        Write-Host "Servidor eliminado de la configuracion local." -ForegroundColor Green
        Write-Host ""
        Write-Host "Para eliminar los datos del mundo en el VPS, ejecuta manualmente:" -ForegroundColor DarkGray
        Write-Host "  docker volume rm <nombre_volumen_minecraft_data>" -ForegroundColor DarkGray
        Write-Host ""

        Write-Log -Level "INFO" -Message "Servidor Minecraft eliminado: $ServerName" -Source "minecraft"
    }
}
