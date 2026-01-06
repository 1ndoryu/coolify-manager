<#
.SYNOPSIS
    Modulo de logging estructurado.
.DESCRIPTION
    Sistema de logs con niveles (DEBUG, INFO, WARN, ERROR) que
    escribe a archivo y opcionalmente a consola.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:LogPath = Join-Path $script:ModuleRoot "logs"
$script:CurrentLogFile = $null
$script:VerboseLogging = $false

function Initialize-Logger {
    <#
    .SYNOPSIS
        Inicializa el sistema de logging
    .PARAMETER Verbose
        Si se habilita logging verbose (DEBUG)
    #>
    param(
        [switch]$VerboseMode
    )
    
    $script:VerboseLogging = $VerboseMode
    
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }
    
    $fecha = Get-Date -Format "yyyy-MM-dd"
    $script:CurrentLogFile = Join-Path $script:LogPath "coolify-manager_$fecha.log"
    
    Write-Log -Level "INFO" -Message "Logger inicializado" -Source "Logger"
}

function Write-Log {
    <#
    .SYNOPSIS
        Escribe un mensaje al log
    .PARAMETER Level
        Nivel del log: DEBUG, INFO, WARN, ERROR
    .PARAMETER Message
        Mensaje a registrar
    .PARAMETER Source
        Fuente del mensaje (comando o modulo)
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Source = "System"
    )
    
    if (-not $script:CurrentLogFile) {
        Initialize-Logger
    }
    
    if ($Level -eq "DEBUG" -and -not $script:VerboseLogging) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$Source] $Message"
    
    Add-Content -Path $script:CurrentLogFile -Value $logEntry -Encoding UTF8
    
    switch ($Level) {
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
    }
}

function Get-LogPath {
    <#
    .SYNOPSIS
        Obtiene la ruta del archivo de log actual
    #>
    if (-not $script:CurrentLogFile) {
        Initialize-Logger
    }
    return $script:CurrentLogFile
}

function Clear-OldLogs {
    <#
    .SYNOPSIS
        Elimina logs mas antiguos que los dias especificados
    .PARAMETER DaysToKeep
        Numero de dias a mantener
    #>
    param(
        [int]$DaysToKeep = 30
    )
    
    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    $oldLogs = Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
    Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    $count = 0
    foreach ($log in $oldLogs) {
        Remove-Item $log.FullName -Force
        $count++
    }
    
    if ($count -gt 0) {
        Write-Log -Level "INFO" -Message "Eliminados $count logs antiguos" -Source "Logger"
    }
    
    return $count
}

function Get-LogEntries {
    <#
    .SYNOPSIS
        Obtiene las ultimas entradas del log
    .PARAMETER Count
        Numero de entradas a obtener
    .PARAMETER Level
        Filtrar por nivel
    #>
    param(
        [int]$Count = 50,
        
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "ALL")]
        [string]$Level = "ALL"
    )
    
    if (-not $script:CurrentLogFile -or -not (Test-Path $script:CurrentLogFile)) {
        return @()
    }
    
    $entries = Get-Content $script:CurrentLogFile -Tail $Count
    
    if ($Level -ne "ALL") {
        $entries = $entries | Where-Object { $_ -match "\[$Level\]" }
    }
    
    return $entries
}

Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Write-Log',
    'Get-LogPath',
    'Clear-OldLogs',
    'Get-LogEntries'
)
