<#
Script temporal para actualizar el docker-compose del stack Minecraft
en Coolify con las optimizaciones de rendimiento (Aikar flags + MEMORY reducido).
#>

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force

$mcUuid = "jkwogowccwws00kc0kggg0o4"

# Leer el template optimizado
$templatePath = Join-Path $PSScriptRoot "templates\minecraft-stack.yaml"
$yaml = Get-Content $templatePath -Raw
$yaml = $yaml -replace '\{\{SERVER_NAME\}\}', 'survival'

Write-Host "YAML a desplegar:" -ForegroundColor Cyan
Write-Host $yaml -ForegroundColor Gray
Write-Host ""

# Codificar en base64
$base64Yaml = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($yaml))

# Actualizar el compose del servicio via API
$config = Get-CoolifyConfig
$headers = @{
    "Authorization" = "Bearer $($config.coolify.apiToken)"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

$body = @{
    docker_compose_raw = $base64Yaml
} | ConvertTo-Json

$url = "$($config.coolify.baseUrl)/api/v1/services/$mcUuid"

Write-Host "Actualizando compose en Coolify..." -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Uri $url -Method PATCH -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "Compose actualizado!" -ForegroundColor Green
}
catch {
    Write-Host "Error al actualizar compose: $($_.Exception.Message)" -ForegroundColor Red
    # Si PATCH falla, intentar PUT
    Write-Host "Intentando PUT..." -ForegroundColor Yellow
    try {
        $result = Invoke-RestMethod -Uri $url -Method PUT -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "Compose actualizado via PUT!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error PUT: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Los cambios del server.properties ya estan aplicados." -ForegroundColor Yellow
        Write-Host "Solo falta reiniciar para que tomen efecto." -ForegroundColor Yellow
    }
}

# Reiniciar el servicio
Write-Host ""
Write-Host "Reiniciando servidor Minecraft..." -ForegroundColor Yellow
Restart-CoolifyService -Uuid $mcUuid
Write-Host "Reinicio solicitado. El servidor estara listo en ~1 minuto." -ForegroundColor Green
