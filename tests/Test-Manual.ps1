<#
.SYNOPSIS
    Script de tests para Coolify Manager (sin SSH directo)
.DESCRIPTION
    Ejecuta tests usando la API de Coolify. No requiere SSH directo.
.EXAMPLE
    .\Test-Manual.ps1
#>

$ErrorActionPreference = "Continue"
$script:TestResults = @()
$script:PassedTests = 0
$script:FailedTests = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $statusIcon = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $statusColor = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "  $statusIcon " -ForegroundColor $statusColor -NoNewline
    Write-Host $TestName -NoNewline
    
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
    
    if ($Passed) { $script:PassedTests++ } 
    else { $script:FailedTests++ }
    
    $script:TestResults += [PSCustomObject]@{
        Test      = $TestName
        Passed    = $Passed
        Message   = $Message
        Timestamp = Get-Date
    }
}

# Cargar configuracion
$ManagerRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ManagerRoot "config\settings.json"
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

Write-TestHeader "COOLIFY MANAGER - TESTS"
Write-Host "  Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  VPS: $($config.vps.ip)"
Write-Host ""

# -----------------------------------------
# TEST 1: API Coolify - Conexion basica
# -----------------------------------------
Write-TestHeader "TEST 1: API Coolify"
$apiOk = $false
try {
    $headers = @{
        "Authorization" = "Bearer $($config.coolify.apiToken)"
        "Content-Type"  = "application/json"
    }
    $apiUrl = "$($config.coolify.baseUrl)/api/v1/version"
    $version = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
    Write-TestResult -TestName "API Coolify conecta" -Passed $true -Message "Version: $version"
    $apiOk = $true
}
catch {
    Write-TestResult -TestName "API Coolify conecta" -Passed $false -Message $_.Exception.Message
}

# -----------------------------------------
# TEST 2: Listar Servicios
# -----------------------------------------
Write-TestHeader "TEST 2: Servicios en Coolify"
$services = @()
if ($apiOk) {
    try {
        $apiUrl = "$($config.coolify.baseUrl)/api/v1/services"
        $services = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        Write-TestResult -TestName "Obtener servicios" -Passed $true -Message "$($services.Count) servicios encontrados"
        
        foreach ($service in $services) {
            $status = $service.status
            $name = $service.name
            $isRunning = $status -match "running"
            Write-TestResult -TestName "  $name" -Passed $isRunning -Message $status
        }
    }
    catch {
        Write-TestResult -TestName "Obtener servicios" -Passed $false -Message $_.Exception.Message
    }
}
else {
    Write-TestResult -TestName "Servicios (omitido)" -Passed $false -Message "API no disponible"
}

# -----------------------------------------
# TEST 3: Configuracion Local
# -----------------------------------------
Write-TestHeader "TEST 3: Configuracion Local"

# Verificar estructura de settings.json
$hasVps = $null -ne $config.vps.ip
$hasCoolify = $null -ne $config.coolify.apiToken
$hasSitios = $config.sitios.Count -gt 0

Write-TestResult -TestName "Config VPS" -Passed $hasVps -Message "IP: $($config.vps.ip)"
Write-TestResult -TestName "Config Coolify" -Passed $hasCoolify -Message "Token configurado"
Write-TestResult -TestName "Sitios registrados" -Passed $hasSitios -Message "$($config.sitios.Count) sitios"

# -----------------------------------------
# TEST 4: Sitios Registrados
# -----------------------------------------
Write-TestHeader "TEST 4: Sitios Registrados"
foreach ($sitio in $config.sitios) {
    $hasStackUuid = -not [string]::IsNullOrEmpty($sitio.stackUuid)
    $uuidPreview = if ($hasStackUuid) { $sitio.stackUuid.Substring(0, 8) + "..." } else { "SIN UUID" }
    Write-TestResult -TestName "$($sitio.nombre)" -Passed $hasStackUuid -Message "$($sitio.dominio) [$uuidPreview]"
}

# -----------------------------------------
# TEST 5: Acceso HTTP a Sitios
# -----------------------------------------
Write-TestHeader "TEST 5: Acceso HTTP"
foreach ($sitio in $config.sitios) {
    try {
        $response = Invoke-WebRequest -Uri $sitio.dominio -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        Write-TestResult -TestName "HTTP $($sitio.nombre)" -Passed $true -Message "Status: $($response.StatusCode)"
    }
    catch {
        $errorMsg = $_.Exception.Message
        # Detectar redirects como OK
        if ($errorMsg -match "302|301" -or $_.Exception.Response.StatusCode -eq 200) {
            Write-TestResult -TestName "HTTP $($sitio.nombre)" -Passed $true -Message "OK (redirect)"
        }
        else {
            $shortMsg = if ($errorMsg.Length -gt 60) { $errorMsg.Substring(0, 60) + "..." } else { $errorMsg }
            Write-TestResult -TestName "HTTP $($sitio.nombre)" -Passed $false -Message $shortMsg
        }
    }
}

# -----------------------------------------
# TEST 6: Modulos PowerShell
# -----------------------------------------
Write-TestHeader "TEST 6: Modulos"
$modulesPath = Join-Path $ManagerRoot "modules"
$requiredModules = @("CoolifyApi.psm1", "SshOperations.psm1", "WordPressManager.psm1")

foreach ($moduleName in $requiredModules) {
    $modulePath = Join-Path $modulesPath $moduleName
    $exists = Test-Path $modulePath
    Write-TestResult -TestName "Modulo $moduleName" -Passed $exists -Message $(if ($exists) { "Existe" } else { "NO ENCONTRADO" })
}

# -----------------------------------------
# TEST 7: Comandos
# -----------------------------------------
Write-TestHeader "TEST 7: Comandos"
$commandsPath = Join-Path $ManagerRoot "commands"
$requiredCommands = @(
    "new-site.ps1", 
    "list-sites.ps1", 
    "restart-site.ps1", 
    "deploy-theme.ps1",
    "import-database.ps1",
    "exec-command.ps1",
    "view-logs.ps1"
)

foreach ($cmdName in $requiredCommands) {
    $cmdPath = Join-Path $commandsPath $cmdName
    $exists = Test-Path $cmdPath
    Write-TestResult -TestName $cmdName -Passed $exists -Message $(if ($exists) { "OK" } else { "FALTA" })
}

# -----------------------------------------
# RESUMEN
# -----------------------------------------
Write-TestHeader "RESUMEN"
$totalTests = $script:PassedTests + $script:FailedTests
$passRate = if ($totalTests -gt 0) { [math]::Round(($script:PassedTests / $totalTests) * 100, 1) } else { 0 }

Write-Host "  Total:    $totalTests tests"
Write-Host "  Pasados:  " -NoNewline
Write-Host "$($script:PassedTests)" -ForegroundColor Green
Write-Host "  Fallidos: " -NoNewline
Write-Host "$($script:FailedTests)" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "  Tasa de exito: " -NoNewline

$rateColor = if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" }
Write-Host "$passRate%" -ForegroundColor $rateColor
Write-Host ""

if ($script:FailedTests -gt 0) {
    Write-Host "  Tests fallidos:" -ForegroundColor Yellow
    $script:TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "    - $($_.Test): $($_.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Guardar resultados
$resultsPath = Join-Path $PSScriptRoot "results_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"
$script:TestResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "  Resultados guardados: $resultsPath" -ForegroundColor DarkGray
Write-Host ""
