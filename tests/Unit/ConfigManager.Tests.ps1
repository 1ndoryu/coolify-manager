<#
.SYNOPSIS
    Tests unitarios para el modulo ConfigManager
.DESCRIPTION
    Ejecutar con: Invoke-Pester -Path .\tests\Unit\ConfigManager.Tests.ps1
    Compatible con Pester 3.4.0+
#>

$modulePath = Join-Path $PSScriptRoot "..\..\modules\Core\ConfigManager.psm1"
Import-Module $modulePath -Force

Describe "ConfigManager - Get-Config" {
    
    It "Retorna configuracion valida" {
        $config = Get-Config -Force
        $config | Should Not BeNullOrEmpty
    }
    
    It "Contiene seccion vps" {
        $config = Get-Config
        $config.vps | Should Not BeNullOrEmpty
        $config.vps.ip | Should Not BeNullOrEmpty
    }
    
    It "Contiene seccion coolify" {
        $config = Get-Config
        $config.coolify | Should Not BeNullOrEmpty
        $config.coolify.baseUrl | Should Not BeNullOrEmpty
    }
    
    It "Contiene seccion sitios" {
        $config = Get-Config
        $config.sitios | Should Not BeNullOrEmpty
    }
}

Describe "ConfigManager - Get-SiteConfig" {
    
    It "Retorna sitio existente" {
        $site = Get-SiteConfig -SiteName "padel"
        $site | Should Not BeNullOrEmpty
        $site.nombre | Should Be "padel"
    }
    
    It "Incluye dominio del sitio" {
        $site = Get-SiteConfig -SiteName "padel"
        $site.dominio | Should Match "https://"
    }
    
    It "Lanza error para sitio inexistente" {
        { Get-SiteConfig -SiteName "no-existe" } | Should Throw
    }
}

Describe "ConfigManager - Get-VpsConfig" {
    
    It "Retorna configuracion VPS" {
        $vps = Get-VpsConfig
        $vps | Should Not BeNullOrEmpty
    }
    
    It "Contiene IP del servidor" {
        $vps = Get-VpsConfig
        $vps.ip | Should Match "\d+\.\d+\.\d+\.\d+"
    }
}

Describe "ConfigManager - Get-CoolifyConfig" {
    
    It "Retorna configuracion Coolify" {
        $coolify = Get-CoolifyConfig
        $coolify | Should Not BeNullOrEmpty
    }
    
    It "Contiene baseUrl" {
        $coolify = Get-CoolifyConfig
        $coolify.baseUrl | Should Match "http"
    }
    
    It "Contiene apiToken" {
        $coolify = Get-CoolifyConfig
        $coolify.apiToken | Should Not BeNullOrEmpty
    }
}

Describe "ConfigManager - Get-AllSites" {
    
    It "Retorna array de sitios" {
        $sites = Get-AllSites
        $sites | Should Not BeNullOrEmpty
        $sites.Count | Should BeGreaterThan 0
    }
    
    It "Cada sitio tiene nombre" {
        $sites = Get-AllSites
        foreach ($site in $sites) {
            $site.nombre | Should Not BeNullOrEmpty
        }
    }
}

Describe "ConfigManager - Get-DbPassword" {
    
    It "Usa variable de entorno especifica si existe" {
        [System.Environment]::SetEnvironmentVariable("DB_PASSWORD_TESTSITE", "secreto123")
        
        $password = Get-DbPassword -SiteName "testsite"
        $password | Should Be "secreto123"
        
        [System.Environment]::SetEnvironmentVariable("DB_PASSWORD_TESTSITE", $null)
    }
    
    It "Usa variable generica como fallback" {
        [System.Environment]::SetEnvironmentVariable("DB_PASSWORD_NUEVOSITIO", $null)
        [System.Environment]::SetEnvironmentVariable("COOLIFY_DB_PASSWORD", "default123")
        
        $password = Get-DbPassword -SiteName "nuevositio"
        $password | Should Be "default123"
        
        [System.Environment]::SetEnvironmentVariable("COOLIFY_DB_PASSWORD", $null)
    }
}
