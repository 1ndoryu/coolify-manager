
$ModulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host "Checking for services..."
try {
    $svcs = Get-CoolifyServices
    $svcs | Select-Object uuid, name, type | Format-Table
}
catch {
    Write-Host "Error listing services: $_"
}

$uuid = "zkcc040cc0scock4kcooowkc"
Write-Host "Trying to start service $uuid via GET /services/$uuid/start (legacy?)"
try {
    Invoke-CoolifyApi -Endpoint "/services/$uuid/start" -Method GET
}
catch {
    Write-Host "GET start failed: $_"
}
