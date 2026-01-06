<#
.SYNOPSIS
    Ejecuta un comando arbitrario en un contenedor WordPress.
.DESCRIPTION
    Permite ejecutar comandos bash o PHP directamente en el contenedor
    WordPress de un sitio especifico.
.PARAMETER SiteName
    Nombre del sitio
.PARAMETER Command
    Comando bash a ejecutar
.PARAMETER PhpCode
    Codigo PHP a ejecutar (alternativa a Command)
.PARAMETER Target
    Contenedor objetivo: wordpress o mariadb (default: wordpress)
.EXAMPLE
    .\exec-command.ps1 -SiteName "padel" -Command "ls -la /var/www/html"
.EXAMPLE
    .\exec-command.ps1 -SiteName "nakomi" -PhpCode "echo get_option('siteurl');"
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteName,
    
    [Parameter(ParameterSetName = "Bash")]
    [string]$Command,
    
    [Parameter(ParameterSetName = "PHP")]
    [string]$PhpCode,
    
    [ValidateSet("wordpress", "mariadb")]
    [string]$Target = "wordpress"
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

<#
Validacion: Verificar que el sitio existe y tiene UUID configurado
#>
try {
    $siteConfig = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Ejecutando comando en sitio: $SiteName" -Source "exec-command"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$stackName = "$SiteName-stack"

if ($Target -eq "wordpress") {
    $containerId = Get-WordPressContainerId -StackName $stackName
}
else {
    $containerId = Get-MariaDbContainerId -StackName $stackName
}

if (-not $containerId) {
    Write-Log -Level "ERROR" -Message "Contenedor $Target no encontrado para: $SiteName" -Source "exec-command"
    Write-Host "No se encontro contenedor $Target para: $SiteName" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Ejecutando en [$Target] de '$SiteName'..." -ForegroundColor Cyan
Write-Host ""

if ($PhpCode) {
    $fullPhpCode = "<?php require '/var/www/html/wp-load.php'; $PhpCode"
    $escapedPhp = $fullPhpCode -replace "'", "'\''"
    $Command = "php -r '$escapedPhp'"
}

$result = Invoke-DockerExec -ContainerId $containerId -Command $Command

Write-Host $result
Write-Host ""
