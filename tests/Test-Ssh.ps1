<#
.SYNOPSIS
    Test SSH de forma aislada
.DESCRIPTION
    Prueba la conexion SSH con timeout explícito.
    Ejecutar manualmente si hay problemas de conexion.
.EXAMPLE
    .\Test-Ssh.ps1
#>

$ErrorActionPreference = "Stop"

# Cargar configuracion
$ManagerRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ManagerRoot "config\settings.json"
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$vpsIp = $config.vps.ip
$vpsUser = $config.vps.user

Write-Host ""
Write-Host "=== TEST SSH ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: $vpsUser@$vpsIp"
Write-Host ""

# Test 1: Ping
Write-Host "1. Testing ping..." -ForegroundColor Yellow
$pingResult = Test-Connection -ComputerName $vpsIp -Count 2 -Quiet
if ($pingResult) {
    Write-Host "   [PASS] Ping OK" -ForegroundColor Green
}
else {
    Write-Host "   [FAIL] No hay respuesta ping" -ForegroundColor Red
    Write-Host "   Verifica conectividad de red" -ForegroundColor Gray
}

# Test 2: Puerto SSH
Write-Host ""
Write-Host "2. Testing puerto 22..." -ForegroundColor Yellow
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($vpsIp, 22, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    
    if ($wait -and $tcpClient.Connected) {
        Write-Host "   [PASS] Puerto 22 abierto" -ForegroundColor Green
        $tcpClient.Close()
    }
    else {
        Write-Host "   [FAIL] Puerto 22 no responde" -ForegroundColor Red
    }
}
catch {
    Write-Host "   [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: SSH Command
Write-Host ""
Write-Host "3. Testing SSH command..." -ForegroundColor Yellow
Write-Host "   Ejecutando: ssh -o ConnectTimeout=10 $vpsUser@$vpsIp 'echo OK'" -ForegroundColor Gray
Write-Host ""
Write-Host "   (Si esto se cuelga, presiona Ctrl+C)" -ForegroundColor DarkGray
Write-Host ""

# Ejecutar SSH con timeout manual
$job = Start-Job -ScriptBlock {
    param($user, $ip)
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$user@$ip" "echo SSH_SUCCESS"
} -ArgumentList $vpsUser, $vpsIp

$completed = Wait-Job $job -Timeout 15

if ($completed) {
    $result = Receive-Job $job
    if ($result -match "SSH_SUCCESS") {
        Write-Host "   [PASS] SSH conecta correctamente" -ForegroundColor Green
    }
    else {
        Write-Host "   [FAIL] SSH respuesta inesperada: $result" -ForegroundColor Red
    }
}
else {
    Stop-Job $job
    Write-Host "   [FAIL] SSH timeout (15 segundos)" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Posibles causas:" -ForegroundColor Yellow
    Write-Host "   - Clave SSH no configurada" -ForegroundColor Gray
    Write-Host "   - Host key verification pendiente" -ForegroundColor Gray
    Write-Host "   - Firewall bloqueando" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Intenta ejecutar manualmente:" -ForegroundColor Yellow
    Write-Host "   ssh $vpsUser@$vpsIp" -ForegroundColor White
}

Remove-Job $job -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== FIN TEST SSH ===" -ForegroundColor Cyan
Write-Host ""
