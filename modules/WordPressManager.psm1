<#
.SYNOPSIS
    Modulo facade de gestion de WordPress en contenedores.
.DESCRIPTION
    Este modulo actua como un punto de entrada unificado para las funciones
    de WordPress. Re-exporta funciones de los modulos especializados:
    - ThemeManager.psm1 (temas)
    - DatabaseManager.psm1 (base de datos)
    - SiteManager.psm1 (configuracion de sitio)
    
    NOTA: Este modulo se mantiene por compatibilidad hacia atras.
    Para nuevos desarrollos, importar directamente los modulos especializados.
#>

$script:ModuleRoot = Split-Path -Parent $PSScriptRoot

<#
Importar modulos especializados del subdirectorio WordPress
#>
$wordpressModulesPath = Join-Path $PSScriptRoot "WordPress"

Import-Module (Join-Path $wordpressModulesPath "ThemeManager.psm1") -Force
Import-Module (Join-Path $wordpressModulesPath "DatabaseManager.psm1") -Force
Import-Module (Join-Path $wordpressModulesPath "SiteManager.psm1") -Force

<#
Re-exportar todas las funciones publicas de los modulos especializados.
Esto mantiene compatibilidad con codigo existente que importa WordPressManager.psm1
#>
Export-ModuleMember -Function @(
    # Desde ThemeManager.psm1
    'Get-GloryConfig',
    'Install-GloryTheme',
    'Update-GloryTheme',
    
    # Desde DatabaseManager.psm1
    'Import-WordPressDatabase',
    'Export-WordPressDatabase',
    
    # Desde SiteManager.psm1
    'Get-SiteConfig',
    'Set-WordPressUrls',
    'New-WordPressAdmin',
    'Get-WordPressOption'
)
