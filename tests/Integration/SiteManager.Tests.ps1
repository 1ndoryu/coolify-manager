<#
.SYNOPSIS
    Tests de integracion para el modulo SiteManager
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Integration\SiteManager.Tests.ps1
    
    IMPORTANTE: Estos tests requieren conexion activa al VPS y Docker.
    Solo ejecutar en entorno de desarrollo/staging.
    
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\WordPress\SiteManager.psm1"
$sshModulePath = Join-Path $PSScriptRoot "..\..\modules\SshOperations.psm1"

Import-Module $sshModulePath -Force
Import-Module $modulePath -Force

Describe "SiteManager - Get-SiteConfig" {
    
    It "Retorna configuracion de sitio existente" {
        $site = Get-SiteConfig -SiteName "padel"
        $site | Should Not BeNullOrEmpty
        $site.nombre | Should Be "padel"
    }
    
    It "Contiene dominio" {
        $site = Get-SiteConfig -SiteName "padel"
        $site.dominio | Should Not BeNullOrEmpty
    }
    
    It "Lanza error para sitio inexistente" {
        { Get-SiteConfig -SiteName "sitio-que-no-existe" } | Should Throw
    }
    
    It "Incluye lista de sitios disponibles en error" {
        try {
            Get-SiteConfig -SiteName "xyz123"
        }
        catch {
            $_.Exception.Message | Should Match "disponibles"
        }
    }
}

Describe "SiteManager - Set-WordPressUrls" {
    
    It "Requiere StackName" {
        { Set-WordPressUrls -Domain "https://test.com" } | Should Throw
    }
    
    It "Requiere Domain" {
        { Set-WordPressUrls -StackName "test-stack" } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    It "Actualiza URLs en WordPress" {
        { Set-WordPressUrls -StackName "padel-stack" -Domain "https://padel.wandori.us" } |
            Should Not Throw
    }
    #>
}

Describe "SiteManager - New-WordPressAdmin" {
    
    It "Requiere StackName" {
        { New-WordPressAdmin -Username "test" -Password "test123" } | Should Throw
    }
    
    It "Requiere Username" {
        { New-WordPressAdmin -StackName "test-stack" -Password "test123" } | Should Throw
    }
    
    It "Requiere Password" {
        { New-WordPressAdmin -StackName "test-stack" -Username "test" } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    It "Crea usuario administrador" {
        $randomUser = "testuser_$(Get-Random)"
        { New-WordPressAdmin -StackName "padel-stack" -Username $randomUser -Password "TestPass123!" } |
            Should Not Throw
    }
    #>
}

Describe "SiteManager - Get-WordPressOption" {
    
    It "Requiere StackName" {
        { Get-WordPressOption -OptionName "siteurl" } | Should Throw
    }
    
    It "Requiere OptionName" {
        { Get-WordPressOption -StackName "test-stack" } | Should Throw
    }
    
    <#
    TESTS COMENTADOS - Requieren ejecucion real en contenedor
    
    It "Obtiene opcion siteurl" {
        $url = Get-WordPressOption -StackName "padel-stack" -OptionName "siteurl"
        $url | Should Match "https?://"
    }
    #>
}
