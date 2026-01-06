<#
.SYNOPSIS
    Importa una base de datos SQL a un sitio WordPress.
.DESCRIPTION
    Sube un archivo .sql al contenedor MariaDB y lo importa.
    Opcionalmente corrige las URLs despues de importar.
.PARAMETER SiteName
    Nombre del sitio destino
.PARAMETER SqlFile
    Ruta al archivo .sql a importar
.PARAMETER FixUrls
    Corrige las URLs al dominio configurado despues de importar
.EXAMPLE
    .\import-database.ps1 -SiteName "padel" -SqlFile "C:\backup\padel.sql"
.EXAMPLE
    .\import-database.ps1 -SiteName "nakomi" -SqlFile ".\nakomi.sql" -FixUrls
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [Parameter(Mandatory)]
    [string]$SqlFile,
    
    [switch]$FixUrls
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "WordPressManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IMPORTACION DE BASE DE DATOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

<#
Validacion: Verificar archivo SQL y sitio
#>
try {
    Test-SqlFileExists -FilePath $SqlFile | Out-Null
    $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Iniciando importacion de BD en: $SiteName" -Source "import-database"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$stackName = "$SiteName-stack"
$fileSize = (Get-Item $SqlFile).Length / 1MB

Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Archivo: $SqlFile" -ForegroundColor White
Write-Host "Tamano: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
Write-Host ""

Write-Host "[1/2] Importando base de datos..." -ForegroundColor Yellow
Import-WordPressDatabase -StackName $stackName -SqlFilePath $SqlFile

if ($FixUrls) {
    Write-Host ""
    Write-Host "[2/2] Corrigiendo URLs..." -ForegroundColor Yellow
    Set-WordPressUrls -StackName $stackName -Domain $sitio.dominio
}
else {
    Write-Host "[2/2] Correccion de URLs omitida (usa -FixUrls para activar)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Importacion completada!" -ForegroundColor Green
Write-Host ""
