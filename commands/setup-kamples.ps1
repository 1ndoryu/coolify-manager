<#
.SYNOPSIS
    Configura Kamples despues de crear el stack.
.DESCRIPTION
    Ejecuta los pasos post-creacion necesarios para Kamples:
    1. Espera que PostgreSQL este healthy
    2. Ejecuta las 20 migraciones SQL secuencialmente
    3. Verifica pgvector
    4. Ejecuta composer install en el contenedor WordPress
    5. Ejecuta npm install + npm run build (Vite)
    6. Sincroniza variables de entorno desde settings.json al contenedor
    7. Verifica FFmpeg
    8. Reinicia Apache
.PARAMETER SiteName
    Nombre del sitio (default: kamples)
.PARAMETER SkipMigrations
    Omitir ejecucion de migraciones SQL
.PARAMETER SkipBuild
    Omitir compilacion de React (npm run build)
.PARAMETER SkipEnvSync
    Omitir sincronizacion de variables de entorno
.PARAMETER MigrationsPath
    Ruta local a las migraciones SQL (default: App/Kamples/Database/migrations)
.EXAMPLE
    .\setup-kamples.ps1
.EXAMPLE
    .\setup-kamples.ps1 -SiteName "kamples" -SkipBuild
.EXAMPLE
    .\setup-kamples.ps1 -SkipMigrations -SkipBuild
#>

param(
    [string]$SiteName = "kamples",

    [switch]$SkipMigrations,

    [switch]$SkipBuild,

    [switch]$SkipEnvSync,

    [string]$MigrationsPath
)

$ErrorActionPreference = "Stop"
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

Import-Module (Join-Path $ModulesPath "CoolifyApi.psm1") -Force
Import-Module (Join-Path $ModulesPath "SshOperations.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\ConfigManager.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP KAMPLES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validar sitio
try {
    $sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid
    Write-Log -Level "INFO" -Message "Iniciando setup de Kamples: $SiteName" -Source "setup-kamples"
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$stackUuid = $sitio.stackUuid
$themeName = $sitio.themeName
if (-not $themeName) { $themeName = "glorytemplate" }

Write-Host "Sitio: $SiteName" -ForegroundColor White
Write-Host "Stack UUID: $stackUuid" -ForegroundColor DarkGray
Write-Host "Tema: $themeName" -ForegroundColor White
Write-Host ""

# Obtener contenedores
$wpContainerId = Get-WordPressContainerId -Uuid $stackUuid
if (-not $wpContainerId) {
    Write-Host "ERROR: No se encontro contenedor WordPress para UUID: $stackUuid" -ForegroundColor Red
    exit 1
}
Write-Host "Contenedor WordPress: $wpContainerId" -ForegroundColor Green

# Obtener contenedor PostgreSQL
$vps = Get-VpsConfig
$sshTarget = "$($vps.user)@$($vps.ip)"
$pgContainerCmd = "docker ps -q -f name=postgres-$stackUuid | head -n 1"
$pgContainerId = (Invoke-SshCommand -Command $pgContainerCmd -Silent).Trim()

if (-not $pgContainerId) {
    # Fallback: buscar por imagen pgvector
    $pgContainerCmd = "docker ps -q -f ancestor=pgvector/pgvector:pg18 | head -n 1"
    $pgContainerId = (Invoke-SshCommand -Command $pgContainerCmd -Silent).Trim()
}

if (-not $pgContainerId) {
    Write-Host "ERROR: No se encontro contenedor PostgreSQL" -ForegroundColor Red
    exit 1
}
Write-Host "Contenedor PostgreSQL: $pgContainerId" -ForegroundColor Green
Write-Host ""

$stepNum = 0
$totalSteps = 7
if ($SkipMigrations) { $totalSteps-- }
if ($SkipBuild) { $totalSteps-- }
if ($SkipEnvSync) { $totalSteps-- }

# ============================================
# PASO 1: Esperar PostgreSQL healthy
# ============================================
$stepNum++
Write-Host "[$stepNum/$totalSteps] Verificando PostgreSQL..." -ForegroundColor Yellow

$pgHealthCmd = "docker exec $pgContainerId pg_isready -U kamples_app -d kamples"
$maxRetries = 10
$retryCount = 0
$pgReady = $false

while ($retryCount -lt $maxRetries -and -not $pgReady) {
    $healthResult = Invoke-SshCommand -Command $pgHealthCmd -Silent
    if ($healthResult -match "accepting connections") {
        $pgReady = $true
        Write-Host "  PostgreSQL esta listo" -ForegroundColor Green
    }
    else {
        $retryCount++
        Write-Host "  Esperando PostgreSQL... ($retryCount/$maxRetries)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

if (-not $pgReady) {
    Write-Host "ERROR: PostgreSQL no respondio despues de $maxRetries intentos" -ForegroundColor Red
    exit 1
}

# Verificar pgvector
$pgvectorCheck = Invoke-SshCommand -Command "docker exec $pgContainerId psql -U kamples_app -d kamples -c `"SELECT extname FROM pg_extension WHERE extname='vector';`"" -Silent
if ($pgvectorCheck -match "vector") {
    Write-Host "  pgvector: activo" -ForegroundColor Green
}
else {
    Write-Host "  pgvector: activando..." -ForegroundColor Yellow
    Invoke-SshCommand -Command "docker exec $pgContainerId psql -U kamples_app -d kamples -c `"CREATE EXTENSION IF NOT EXISTS vector;`"" -Silent
    Write-Host "  pgvector: activado" -ForegroundColor Green
}

# ============================================
# PASO 2: Migraciones SQL
# ============================================
if (-not $SkipMigrations) {
    $stepNum++
    Write-Host ""
    Write-Host "[$stepNum/$totalSteps] Ejecutando migraciones SQL..." -ForegroundColor Yellow

    # Determinar ruta de migraciones
    if (-not $MigrationsPath) {
        # Buscar en el tema dentro del contenedor
        $MigrationsPath = "/var/www/html/wp-content/themes/$themeName/App/Kamples/Database/migrations"
    }

    # Listar migraciones disponibles en el contenedor
    $listCmd = "docker exec $wpContainerId ls $MigrationsPath/*.sql 2>/dev/null | sort"
    $migrationFiles = (Invoke-SshCommand -Command $listCmd -Silent) -split "`n" | Where-Object { $_.Trim() }

    # Excluir variantes de v001 que no son para produccion
    $excluir = @('v001_local_sin_pgvector.sql', 'v001_schema_inicial.sql')
    $migrationFiles = $migrationFiles | Where-Object {
        $fileName = Split-Path $_ -Leaf
        $fileName -notin $excluir -and $fileName.Trim()
    }

    $migCount = 0
    $migTotal = $migrationFiles.Count
    Write-Host "  Encontradas $migTotal migraciones" -ForegroundColor Cyan

    foreach ($sqlFile in $migrationFiles) {
        $sqlFile = $sqlFile.Trim()
        if (-not $sqlFile) { continue }
        
        $fileName = Split-Path $sqlFile -Leaf
        $migCount++
        Write-Host "  [$migCount/$migTotal] $fileName" -ForegroundColor DarkGray -NoNewline

        # Copiar SQL del contenedor WP al contenedor PG y ejecutar
        $execCmd = "docker exec $wpContainerId cat `"$sqlFile`" | docker exec -i $pgContainerId psql -U kamples_app -d kamples 2>&1"
        $result = Invoke-SshCommand -Command $execCmd -Silent

        if ($LASTEXITCODE -eq 0 -or $result -match "CREATE|ALTER|INSERT|UPDATE|already exists") {
            Write-Host " OK" -ForegroundColor Green
        }
        else {
            Write-Host " WARN" -ForegroundColor Yellow
            Write-Host "    $result" -ForegroundColor DarkYellow
        }
    }

    Write-Host "  Migraciones completadas" -ForegroundColor Green
}

# ============================================
# PASO 3: Sincronizar variables de entorno
# ============================================
if (-not $SkipEnvSync) {
    $stepNum++
    Write-Host ""
    Write-Host "[$stepNum/$totalSteps] Sincronizando variables de entorno..." -ForegroundColor Yellow

    $siteEnv = $null
    if ($sitio.PSObject.Properties['env']) {
        $siteEnv = $sitio.env
    }

    if ($siteEnv) {
        # Construir contenido .env
        $envLines = @(
            "# Generado automaticamente por coolify-manager setup-kamples"
            "# $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            ""
        )

        foreach ($prop in $siteEnv.PSObject.Properties) {
            $value = $prop.Value
            
            # Expandir variables ${...} desde env del host
            if ($value -match '\$\{([^}]+)\}') {
                $varName = $Matches[1]
                $envValue = [System.Environment]::GetEnvironmentVariable($varName)
                if ($envValue) {
                    $value = $value -replace [regex]::Escape($Matches[0]), $envValue
                }
                else {
                    Write-Host "  WARN: Variable `${$varName}` no encontrada en entorno local" -ForegroundColor Yellow
                }
            }

            $envLines += "$($prop.Name)=$value"
        }

        $envContent = $envLines -join "`n"
        $themePath = "/var/www/html/wp-content/themes/$themeName"

        # Escribir .env en el contenedor
        $envBytes = [System.Text.Encoding]::UTF8.GetBytes($envContent)
        $envBase64 = [Convert]::ToBase64String($envBytes)
        
        $writeCmd = "docker exec $wpContainerId bash -c 'echo $envBase64 | base64 -d > $themePath/.env'"
        Invoke-SshCommand -Command $writeCmd -Silent

        # Permisos
        Invoke-SshCommand -Command "docker exec $wpContainerId chown www-data:www-data $themePath/.env" -Silent
        Invoke-SshCommand -Command "docker exec $wpContainerId chmod 600 $themePath/.env" -Silent

        $envCount = ($siteEnv.PSObject.Properties | Measure-Object).Count
        Write-Host "  $envCount variables sincronizadas a $themePath/.env" -ForegroundColor Green
    }
    else {
        Write-Host "  Sin variables de entorno configuradas en settings.json" -ForegroundColor DarkGray
    }
}

# ============================================
# PASO 4: Composer install
# ============================================
$stepNum++
Write-Host ""
Write-Host "[$stepNum/$totalSteps] Ejecutando composer install..." -ForegroundColor Yellow

$composerScript = @"
#!/bin/bash
set -e
export COMPOSER_NO_INTERACTION=1
cd /var/www/html/wp-content/themes/$themeName
if [ -f composer.json ]; then
    composer install --no-dev --optimize-autoloader
    echo "[SUCCESS] Composer install completado"
else
    echo "[WARN] No se encontro composer.json"
fi
"@

Invoke-DockerExec -ContainerId $wpContainerId -Command $composerScript

# ============================================
# PASO 5: npm install + build (Vite)
# ============================================
if (-not $SkipBuild) {
    $stepNum++
    Write-Host ""
    Write-Host "[$stepNum/$totalSteps] Ejecutando npm install + build..." -ForegroundColor Yellow

    $buildScript = @"
#!/bin/bash
set -e

THEME_PATH="/var/www/html/wp-content/themes/$themeName"

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "[INFO] Instalando Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "[INFO] Node: `$(node -v)"
echo "[INFO] npm: `$(npm -v)"

# Root install (instala subdeps via postinstall)
cd `$THEME_PATH
if [ -f package.json ]; then
    echo "[INFO] npm install (root)..."
    npm install
fi

# Build principal (Vite)
echo "[INFO] npm run build..."
npm run build

# Corregir permisos
chown -R www-data:www-data `$THEME_PATH

echo "[SUCCESS] Build completado"
"@

    Invoke-DockerExec -ContainerId $wpContainerId -Command $buildScript
}

# ============================================
# PASO 6: Verificar FFmpeg
# ============================================
$stepNum++
Write-Host ""
Write-Host "[$stepNum/$totalSteps] Verificando FFmpeg..." -ForegroundColor Yellow

$ffmpegResult = Invoke-SshCommand -Command "docker exec $wpContainerId ffmpeg -version 2>&1 | head -1" -Silent
if ($ffmpegResult -match "ffmpeg version") {
    Write-Host "  FFmpeg: $($ffmpegResult.Trim())" -ForegroundColor Green
}
else {
    Write-Host "  WARN: FFmpeg no disponible. Instalar en el Dockerfile." -ForegroundColor Yellow
}

$ffprobeResult = Invoke-SshCommand -Command "docker exec $wpContainerId ffprobe -version 2>&1 | head -1" -Silent
if ($ffprobeResult -match "ffprobe version") {
    Write-Host "  FFprobe: OK" -ForegroundColor Green
}
else {
    Write-Host "  WARN: FFprobe no disponible." -ForegroundColor Yellow
}

# ============================================
# PASO 7: Permisos uploads + reiniciar Apache
# ============================================
$stepNum++
Write-Host ""
Write-Host "[$stepNum/$totalSteps] Configurando permisos y reiniciando Apache..." -ForegroundColor Yellow

$permScript = @"
#!/bin/bash
# Crear directorio de uploads kamples si no existe
mkdir -p /var/www/html/wp-content/uploads/kamples
chown -R www-data:www-data /var/www/html/wp-content/uploads/kamples
chmod -R 755 /var/www/html/wp-content/uploads/kamples

# Reiniciar Apache para cargar extensiones PHP
apache2ctl graceful

echo "[SUCCESS] Permisos y Apache configurados"
"@

Invoke-DockerExec -ContainerId $wpContainerId -Command $permScript

# ============================================
# RESUMEN
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SETUP KAMPLES COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Contenedor WP: $wpContainerId" -ForegroundColor Cyan
Write-Host "Contenedor PG: $pgContainerId" -ForegroundColor Cyan
Write-Host "Dominio: $($sitio.dominio)" -ForegroundColor White
Write-Host ""
if (-not $SkipMigrations) { Write-Host "  Migraciones SQL: $migTotal ejecutadas" -ForegroundColor Gray }
if (-not $SkipEnvSync) { Write-Host "  Variables .env: sincronizadas" -ForegroundColor Gray }
Write-Host "  Composer: instalado" -ForegroundColor Gray
if (-not $SkipBuild) { Write-Host "  Vite build: completado" -ForegroundColor Gray }
Write-Host "  FFmpeg: verificado" -ForegroundColor Gray
Write-Host "  Apache: reiniciado" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANTE: WP_DEBUG debe ser FALSE en produccion (SchemaRegistry)" -ForegroundColor Yellow
Write-Host ""

Write-Log -Level "INFO" -Message "Setup Kamples completado para $SiteName" -Source "setup-kamples"
