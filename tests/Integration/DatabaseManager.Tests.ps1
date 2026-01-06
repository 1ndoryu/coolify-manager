<#
.SYNOPSIS
    Tests de integracion para el modulo DatabaseManager
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Integration\DatabaseManager.Tests.ps1
    
    IMPORTANTE: Estos tests requieren conexion activa al VPS y Docker.
    Solo ejecutar en entorno de desarrollo/staging.
    
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\WordPress\DatabaseManager.psm1"
$sshModulePath = Join-Path $PSScriptRoot "..\..\modules\SshOperations.psm1"

Import-Module $sshModulePath -Force
Import-Module $modulePath -Force

Describe "DatabaseManager - Import-WordPressDatabase" {
    
    It "Requiere StackName" {
        { Import-WordPressDatabase -SqlFilePath "test.sql" } | Should Throw
    }
    
    It "Requiere SqlFilePath" {
        { Import-WordPressDatabase -StackName "test-stack" } | Should Throw
    }
    
    It "Rechaza archivo SQL inexistente" {
        { Import-WordPressDatabase -StackName "test-stack" -SqlFilePath "C:\no\existe.sql" } | 
        Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    Context "Con archivo SQL valido" {
        BeforeAll {
            $script:tempSql = Join-Path $env:TEMP "test_$(Get-Random).sql"
            "SELECT 1;" | Out-File $script:tempSql -Encoding UTF8
        }
        
        AfterAll {
            if (Test-Path $script:tempSql) {
                Remove-Item $script:tempSql -Force
            }
        }
        
        It "Importa archivo SQL correctamente" {
            { Import-WordPressDatabase -StackName "padel-stack" -SqlFilePath $script:tempSql } | 
                Should Not Throw
        }
    }
    #>
}

Describe "DatabaseManager - Export-WordPressDatabase" {
    
    It "Requiere StackName" {
        { Export-WordPressDatabase -OutputPath "backup.sql" } | Should Throw
    }
    
    It "Requiere OutputPath" {
        { Export-WordPressDatabase -StackName "test-stack" } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    It "Exporta BD a archivo local" {
        $outputPath = Join-Path $env:TEMP "backup_$(Get-Random).sql"
        
        { Export-WordPressDatabase -StackName "padel-stack" -OutputPath $outputPath } | 
            Should Not Throw
        
        Test-Path $outputPath | Should Be $true
        
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
    }
    #>
}
