<#
.SYNOPSIS
    Registro dinamico de comandos para Coolify Manager.
.DESCRIPTION
    Este modulo gestiona el registro y descubrimiento de comandos disponibles.
    Permite agregar nuevos comandos sin modificar manager.ps1.
    
    Cada comando se define en el directorio commands/ con un archivo .ps1
    y opcionalmente un archivo .json con metadatos.
#>

function Get-AvailableCommands {
    <#
    .SYNOPSIS
        Obtiene la lista de comandos disponibles
    .OUTPUTS
        Array de objetos con info de cada comando
    #>
    $commandsPath = Join-Path $PSScriptRoot "..\commands"
    $commands = @()
    
    Get-ChildItem -Path $commandsPath -Filter "*.ps1" | ForEach-Object {
        $scriptFile = $_
        $baseName = $scriptFile.BaseName
        $alias = Get-CommandAlias -CommandName $baseName
        
        $metadataFile = Join-Path $commandsPath "$baseName.json"
        if (Test-Path $metadataFile) {
            $metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
        }
        else {
            $metadata = Get-DefaultMetadata -ScriptPath $scriptFile.FullName -Alias $alias
        }
        
        $commands += @{
            Name        = $baseName
            Alias       = $alias
            ScriptPath  = $scriptFile.FullName
            Description = $metadata.description
            Examples    = $metadata.examples
            Category    = $metadata.category
        }
    }
    
    return $commands
}

function Get-CommandAlias {
    <#
    .SYNOPSIS
        Obtiene el alias corto de un comando basado en su nombre de archivo
    .PARAMETER CommandName
        Nombre del archivo sin extension (ej: "new-site")
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )
    
    $aliasMap = @{
        "new-site"        = "new"
        "list-sites"      = "list"
        "restart-site"    = "restart"
        "deploy-theme"    = "deploy"
        "import-database" = "import"
        "exec-command"    = "exec"
        "view-logs"       = "logs"
    }
    
    if ($aliasMap.ContainsKey($CommandName)) {
        return $aliasMap[$CommandName]
    }
    
    return $CommandName -replace '-.*', ''
}

function Get-DefaultMetadata {
    <#
    .SYNOPSIS
        Genera metadatos por defecto extrayendo info del script
    .PARAMETER ScriptPath
        Ruta al archivo .ps1
    .PARAMETER Alias
        Alias del comando
    #>
    param(
        [string]$ScriptPath,
        [string]$Alias
    )
    
    $content = Get-Content $ScriptPath -Raw
    $description = ""
    $category = "general"
    
    if ($content -match '\.SYNOPSIS\s*\n\s*(.+)') {
        $description = $Matches[1].Trim()
    }
    
    if ($Alias -in @("new", "restart")) {
        $category = "sitios"
    }
    elseif ($Alias -in @("deploy", "import")) {
        $category = "despliegue"
    }
    elseif ($Alias -in @("exec", "logs")) {
        $category = "debug"
    }
    
    return @{
        description = $description
        examples    = @()
        category    = $category
    }
}

function Invoke-Command {
    <#
    .SYNOPSIS
        Ejecuta un comando registrado por su alias
    .PARAMETER Alias
        Alias del comando (ej: "new", "list", "restart")
    .PARAMETER Arguments
        Argumentos a pasar al comando
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Alias,
        
        [string[]]$Arguments
    )
    
    $commands = Get-AvailableCommands
    $command = $commands | Where-Object { $_.Alias -eq $Alias -or $_.Name -eq $Alias }
    
    if (-not $command) {
        $availableAliases = ($commands | ForEach-Object { $_.Alias }) -join ", "
        throw "Comando '$Alias' no encontrado. Comandos disponibles: $availableAliases"
    }
    
    & $command.ScriptPath @Arguments
}

function Get-CommandInfo {
    <#
    .SYNOPSIS
        Obtiene informacion detallada de un comando
    .PARAMETER Alias
        Alias del comando
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Alias
    )
    
    $commands = Get-AvailableCommands
    $command = $commands | Where-Object { $_.Alias -eq $Alias }
    
    if (-not $command) {
        throw "Comando '$Alias' no encontrado"
    }
    
    return $command
}

function Show-CommandsTable {
    <#
    .SYNOPSIS
        Muestra una tabla formateada de comandos disponibles
    #>
    $commands = Get-AvailableCommands
    
    Write-Host ""
    Write-Host "  COMANDOS DISPONIBLES" -ForegroundColor Cyan
    Write-Host "  ====================" -ForegroundColor Cyan
    Write-Host ""
    
    $commands | ForEach-Object {
        $maxAliasLen = 10
        $alias = $_.Alias.PadRight($maxAliasLen)
        Write-Host "    $alias " -ForegroundColor Green -NoNewline
        Write-Host $_.Description
    }
    
    Write-Host ""
}

Export-ModuleMember -Function @(
    'Get-AvailableCommands',
    'Get-CommandAlias',
    'Get-CommandInfo',
    'Invoke-Command',
    'Show-CommandsTable'
)
