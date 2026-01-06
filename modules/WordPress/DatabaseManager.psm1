<#
.SYNOPSIS
    Modulo de gestion de base de datos WordPress.
.DESCRIPTION
    Funciones para importar, exportar y gestionar bases de datos
    de instalaciones WordPress en contenedores Docker.
#>

$script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "SshOperations.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\ConfigManager.psm1") -Force
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "Core\Logger.psm1") -Force

function Import-WordPressDatabase {
    <#
    .SYNOPSIS
        Importa un archivo SQL a la base de datos del WordPress
    .DESCRIPTION
        Copia un archivo SQL local al contenedor MariaDB y lo importa.
        Usa credenciales seguras obtenidas desde ConfigManager.
    .PARAMETER StackName
        Nombre del stack (ej: "padel-stack")
    .PARAMETER SqlFilePath
        Ruta local al archivo .sql
    .PARAMETER DbName
        Nombre de la base de datos (default: wordpress)
    .PARAMETER SiteName
        Nombre del sitio para obtener credenciales. Si no se proporciona,
        se intenta extraer del StackName.
    .EXAMPLE
        Import-WordPressDatabase -StackName "padel-stack" -SqlFilePath "C:\backup.sql"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$SqlFilePath,
        
        [string]$DbName = "wordpress",
        
        [string]$SiteName
    )
    
    Write-Log -Level INFO -Message "Importando BD para $StackName desde $SqlFilePath" -Command "Import-WordPressDatabase"
    
    if (-not (Test-Path $SqlFilePath)) {
        $errorMsg = "Archivo SQL no encontrado: $SqlFilePath"
        Write-Log -Level ERROR -Message $errorMsg -Command "Import-WordPressDatabase"
        throw $errorMsg
    }
    
    $mariadbId = Get-MariaDbContainerId -StackName $StackName
    
    if (-not $mariadbId) {
        $errorMsg = "No se encontro contenedor MariaDB para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Command "Import-WordPressDatabase"
        throw $errorMsg
    }
    
    Write-Host "Importando base de datos..." -ForegroundColor Yellow
    
    Copy-FileToContainer -LocalPath $SqlFilePath -ContainerId $mariadbId -ContainerPath "/tmp/import.sql"
    
    <#
    Obtencion segura del password:
    1. Si se proporciona SiteName, usa Get-DbPassword
    2. Si no, intenta extraer el nombre del StackName (formato: nombre-stack)
    3. Busca en variables de entorno: DB_PASSWORD_SITENAME, COOLIFY_DB_PASSWORD
    4. Ultimo recurso: config file
    #>
    if (-not $SiteName) {
        $SiteName = $StackName -replace '-stack$', ''
    }
    
    try {
        $dbPassword = Get-DbPassword -SiteName $SiteName
        Write-Log -Level DEBUG -Message "Password obtenido para sitio: $SiteName" -Command "Import-WordPressDatabase"
    }
    catch {
        Write-Warning "No se encontro password especifico. Usando variable COOLIFY_DB_PASSWORD"
        Write-Log -Level WARN -Message "Usando fallback COOLIFY_DB_PASSWORD" -Command "Import-WordPressDatabase"
        $dbPassword = [System.Environment]::GetEnvironmentVariable("COOLIFY_DB_PASSWORD")
        if (-not $dbPassword) {
            $errorMsg = "No se encontro password de BD. Configure COOLIFY_DB_PASSWORD o DB_PASSWORD_$($SiteName.ToUpper())"
            Write-Log -Level ERROR -Message $errorMsg -Command "Import-WordPressDatabase"
            throw $errorMsg
        }
    }
    
    $importCmd = "mariadb -u manager -p'$dbPassword' $DbName < /tmp/import.sql && rm /tmp/import.sql"
    Invoke-DockerExec -ContainerId $mariadbId -Command $importCmd
    
    Write-Log -Level INFO -Message "BD importada exitosamente para $StackName" -Command "Import-WordPressDatabase"
    Write-Host "Base de datos importada exitosamente!" -ForegroundColor Green
}

function Export-WordPressDatabase {
    <#
    .SYNOPSIS
        Exporta la base de datos de WordPress a un archivo SQL
    .DESCRIPTION
        Ejecuta mysqldump en el contenedor MariaDB y descarga el archivo resultante.
    .PARAMETER StackName
        Nombre del stack
    .PARAMETER OutputPath
        Ruta local donde guardar el archivo .sql
    .PARAMETER DbName
        Nombre de la base de datos (default: wordpress)
    .PARAMETER SiteName
        Nombre del sitio para obtener credenciales
    .EXAMPLE
        Export-WordPressDatabase -StackName "padel-stack" -OutputPath "C:\backup.sql"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StackName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$DbName = "wordpress",
        
        [string]$SiteName
    )
    
    Write-Log -Level INFO -Message "Exportando BD de $StackName a $OutputPath" -Command "Export-WordPressDatabase"
    
    $mariadbId = Get-MariaDbContainerId -StackName $StackName
    
    if (-not $mariadbId) {
        $errorMsg = "No se encontro contenedor MariaDB para el stack: $StackName"
        Write-Log -Level ERROR -Message $errorMsg -Command "Export-WordPressDatabase"
        throw $errorMsg
    }
    
    if (-not $SiteName) {
        $SiteName = $StackName -replace '-stack$', ''
    }
    
    try {
        $dbPassword = Get-DbPassword -SiteName $SiteName
    }
    catch {
        $dbPassword = [System.Environment]::GetEnvironmentVariable("COOLIFY_DB_PASSWORD")
        if (-not $dbPassword) {
            throw "No se encontro password de BD"
        }
    }
    
    Write-Host "Exportando base de datos..." -ForegroundColor Yellow
    
    $exportCmd = "mysqldump -u manager -p'$dbPassword' $DbName > /tmp/export.sql"
    Invoke-DockerExec -ContainerId $mariadbId -Command $exportCmd
    
    Copy-FileFromContainer -ContainerId $mariadbId -ContainerPath "/tmp/export.sql" -LocalPath $OutputPath
    
    Invoke-DockerExec -ContainerId $mariadbId -Command "rm /tmp/export.sql"
    
    Write-Log -Level INFO -Message "BD exportada exitosamente a $OutputPath" -Command "Export-WordPressDatabase"
    Write-Host "Base de datos exportada a: $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function @(
    'Import-WordPressDatabase',
    'Export-WordPressDatabase'
)
