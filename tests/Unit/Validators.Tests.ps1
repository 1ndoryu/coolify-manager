<#
.SYNOPSIS
    Tests unitarios para el modulo Validators
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Unit\Validators.Tests.ps1
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\Core\Validators.psm1"
Import-Module $modulePath -Force

Describe "Validators - Test-DomainFormat" {
    
    It "Acepta HTTPS valido" {
        $result = Test-DomainFormat -Domain "https://example.com"
        $result | Should Be $true
    }
    
    It "Acepta HTTP valido" {
        $result = Test-DomainFormat -Domain "http://example.com"
        $result | Should Be $true
    }
    
    It "Acepta subdominio" {
        $result = Test-DomainFormat -Domain "https://api.example.com"
        $result | Should Be $true
    }
    
    It "Rechaza dominio sin protocolo" {
        { Test-DomainFormat -Domain "example.com" } | Should Throw
    }
    
    It "Rechaza dominio con espacios" {
        { Test-DomainFormat -Domain "https://example .com" } | Should Throw
    }
    
    It "Acepta IP con protocolo" {
        $result = Test-DomainFormat -Domain "http://192.168.1.1"
        $result | Should Be $true
    }
}

Describe "Validators - Test-SiteExists" {
    
    It "Retorna sitio si existe" {
        $site = Test-SiteExists -SiteName "padel"
        $site | Should Not BeNullOrEmpty
        $site.nombre | Should Be "padel"
    }
    
    It "Lanza error si no existe" {
        { Test-SiteExists -SiteName "sitio-inexistente" } | Should Throw
    }
}

Describe "Validators - Test-StackUuidExists" {
    
    It "Retorna true si tiene UUID" {
        $result = Test-StackUuidExists -SiteName "padel"
        $result | Should Be $true
    }
    
    It "Retorna false si no tiene UUID" {
        $result = Test-StackUuidExists -SiteName "guillermo"
        $result | Should Be $false
    }
}

Describe "Validators - Test-SqlFileExists" {
    
    It "Acepta archivo existente" {
        $tempFile = Join-Path $env:TEMP "test_$(Get-Random).sql"
        "SELECT 1" | Out-File $tempFile
        
        $result = Test-SqlFileExists -FilePath $tempFile
        $result | Should Be $true
        
        Remove-Item $tempFile -Force
    }
    
    It "Rechaza archivo inexistente" {
        { Test-SqlFileExists -FilePath "C:\no\existe.sql" } | Should Throw
    }
}

Describe "Validators - Assert-SiteReady" {
    
    It "Retorna sitio si esta listo" {
        $site = Assert-SiteReady -SiteName "padel" -RequireUuid
        $site | Should Not BeNullOrEmpty
    }
    
    It "Lanza error si requiere UUID y no tiene" {
        { Assert-SiteReady -SiteName "guillermo" -RequireUuid } | Should Throw
    }
}
