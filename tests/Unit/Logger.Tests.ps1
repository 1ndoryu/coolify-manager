<#
.SYNOPSIS
    Tests unitarios para el modulo Logger
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Unit\Logger.Tests.ps1
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\Core\Logger.psm1"
Import-Module $modulePath -Force

Describe "Logger - Initialize-Logger" {
    
    It "Crea archivo de log" {
        Initialize-Logger
        $logPath = Get-LogPath
        Test-Path $logPath | Should Be $true
    }
    
    It "El archivo sigue formato de fecha" {
        Initialize-Logger
        $logPath = Get-LogPath
        $logPath | Should Match "coolify-manager_\d{4}-\d{2}-\d{2}\.log"
    }
}

Describe "Logger - Write-Log" {
    
    It "Escribe al archivo de log" {
        Initialize-Logger
        $testMessage = "Test-$(Get-Random)"
        
        Write-Log -Level "INFO" -Message $testMessage -Source "Test"
        
        $logPath = Get-LogPath
        $content = Get-Content $logPath -Raw
        $content | Should Match $testMessage
    }
    
    It "Incluye timestamp" {
        Initialize-Logger
        Write-Log -Level "INFO" -Message "Mensaje de prueba" -Source "Test"
        
        $logPath = Get-LogPath
        $content = Get-Content $logPath -Raw
        $content | Should Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
    }
    
    It "Incluye nivel INFO" {
        Initialize-Logger
        $testId = "ID-$(Get-Random)"
        Write-Log -Level "INFO" -Message $testId -Source "Test"
        
        $logPath = Get-LogPath
        $content = Get-Content $logPath -Raw
        $content | Should Match "\[INFO\]"
    }
    
    It "Incluye nivel WARN" {
        Initialize-Logger
        $testId = "WARN-$(Get-Random)"
        Write-Log -Level "WARN" -Message $testId -Source "Test"
        
        $logPath = Get-LogPath
        $content = Get-Content $logPath -Raw
        $content | Should Match "\[WARN\]"
    }
    
    It "Incluye nivel ERROR" {
        Initialize-Logger
        $testId = "ERROR-$(Get-Random)"
        Write-Log -Level "ERROR" -Message $testId -Source "Test"
        
        $logPath = Get-LogPath
        $content = Get-Content $logPath -Raw
        $content | Should Match "\[ERROR\]"
    }
}

Describe "Logger - Get-LogEntries" {
    
    It "Retorna entradas del log" {
        Initialize-Logger
        Write-Log -Level "INFO" -Message "Entry para test" -Source "Test"
        
        $entries = Get-LogEntries -Count 5
        $entries | Should Not BeNullOrEmpty
    }
    
    It "Filtra por nivel ERROR" {
        Initialize-Logger
        Write-Log -Level "ERROR" -Message "Error de prueba filtro" -Source "Test"
        
        $entries = Get-LogEntries -Count 50 -Level "ERROR"
        $entries | Should Not BeNullOrEmpty
    }
}
