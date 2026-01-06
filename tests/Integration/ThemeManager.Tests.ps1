<#
.SYNOPSIS
    Tests de integracion para el modulo ThemeManager
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Integration\ThemeManager.Tests.ps1
    
    IMPORTANTE: Estos tests requieren conexion activa al VPS y Docker.
    Solo ejecutar en entorno de desarrollo/staging.
    
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\WordPress\ThemeManager.psm1"
$sshModulePath = Join-Path $PSScriptRoot "..\..\modules\SshOperations.psm1"

Import-Module $sshModulePath -Force
Import-Module $modulePath -Force

Describe "ThemeManager - Get-GloryConfig" {
    
    It "Retorna configuracion de Glory" {
        $config = Get-GloryConfig
        $config | Should Not BeNullOrEmpty
    }
    
    It "Contiene templateRepo" {
        $config = Get-GloryConfig
        $config.templateRepo | Should Not BeNullOrEmpty
        $config.templateRepo | Should Match "github\.com"
    }
    
    It "Contiene libraryRepo" {
        $config = Get-GloryConfig
        $config.libraryRepo | Should Not BeNullOrEmpty
        $config.libraryRepo | Should Match "github\.com"
    }
}

Describe "ThemeManager - Install-GloryTheme" {
    
    BeforeAll {
        $script:testStackName = "padel-stack"
    }
    
    It "Requiere StackName" {
        { Install-GloryTheme } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    Descomentar solo en entorno de staging
    
    It "Instala tema en contenedor existente" {
        { Install-GloryTheme -StackName $script:testStackName -SkipReact } | 
            Should Not Throw
    }
    #>
}

Describe "ThemeManager - Update-GloryTheme" {
    
    It "Requiere StackName" {
        { Update-GloryTheme } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    It "Actualiza tema existente" {
        { Update-GloryTheme -StackName "padel-stack" } | Should Not Throw
    }
    #>
}
