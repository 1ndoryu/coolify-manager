# Plan de Testing y Refactorización - Coolify Manager

**Fecha:** 2026-01-05  
**Version actual:** 1.0.0  
**Objetivo:** Validar, asegurar calidad y preparar para escalabilidad

---

## Resultados de Tests (2026-01-05)

| Test          | Resultado | Notas                              |
| ------------- | --------- | ---------------------------------- |
| API Coolify   | ✅ PASS    | v4.0.0-beta.460                    |
| Servicios (5) | ⚠️ 4/5     | 1 servicio "Wordpress" en `exited` |
| Configuración | ✅ PASS    | VPS, Coolify, Sitios OK            |
| Sitios (4)    | ⚠️ 3/4     | `guillermo` sin UUID               |
| HTTP Acceso   | ✅ PASS    | Todos responden 200                |
| Módulos (3)   | ✅ PASS    | Todos existen                      |
| Comandos (7)  | ✅ PASS    | Todos existen                      |
| **TOTAL**     | **92.9%** | 26/28 tests pasaron                |

**Problemas detectados:**
1. Servicio "Wordpress" genérico en estado `exited`
2. Sitio `guillermo` sin stackUuid configurado

---

## 1. Resumen Ejecutivo

### Estado Actual

| Componente    | Archivos | Lineas | Estado                    |
| ------------- | -------- | ------ | ------------------------- |
| Modulos       | 3        | ~750   | Funcional, sin tests      |
| Comandos      | 7        | ~450   | Funcional, sin validacion |
| Configuracion | 1        | 54     | Contiene datos sensibles  |
| Templates     | 1        | 26     | Basico                    |

### Problemas Identificados

1. **Sin tests automatizados** - Riesgo de regresiones
2. **Hardcoded password** en `Import-WordPressDatabase` (linea 236)
3. **Sin validacion de entrada** en comandos
4. **Sin manejo de errores robusto** - Solo `throw` basico
5. **Configuracion sensible** expuesta en JSON
6. **Sin logging estructurado** - Solo `Write-Host`

---

## 2. Estrategia de Testing

### 2.1 Niveles de Test

```
┌─────────────────────────────────────────────┐
│           TESTS E2E (Manuales)              │
│  Flujo completo: crear sitio -> verificar   │
├─────────────────────────────────────────────┤
│         TESTS DE INTEGRACION                │
│  API Coolify + SSH + Docker combinados      │
├─────────────────────────────────────────────┤
│           TESTS UNITARIOS                   │
│  Funciones aisladas con mocks               │
└─────────────────────────────────────────────┘
```

### 2.2 Orden de Implementacion

1. **Fase 1: Tests Manuales** - Verificar que todo funcione (HOY)
2. **Fase 2: Tests Unitarios** - Cubrir funciones criticas
3. **Fase 3: Tests de Integracion** - Flujos completos

---

## 3. Plan de Tests Manuales (Fase 1)

### 3.1 Pre-requisitos

- [ ] Acceso SSH al VPS (66.94.100.241)
- [ ] Token API Coolify valido
- [ ] Sitio de prueba disponible (ej: "guillermo" o crear "test-site")

### 3.2 Checklist de Tests Manuales

#### TEST-001: Verificar Conexion SSH

```powershell
# Ejecutar desde: .agent\coolify-manager\
.\manager.ps1 status
```

**Resultado esperado:**
- SSH: Conectado (verde)
- Coolify API: OK (verde)
- Servicios: [numero] (numero > 0)

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-002: Listar Sitios

```powershell
.\manager.ps1 list
.\manager.ps1 list -Detailed
```

**Resultado esperado:**
- Lista todos los sitios de settings.json
- Muestra estado [OK] para sitios activos
- Con -Detailed muestra contenedores Docker

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-003: Ejecutar Comando Bash

```powershell
.\manager.ps1 exec -SiteName "padel" -Command "ls -la /var/www/html"
```

**Resultado esperado:**
- Muestra listado de archivos WordPress
- Incluye wp-config.php, wp-content, etc.

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-004: Ejecutar Codigo PHP

```powershell
.\manager.ps1 exec -SiteName "padel" -PhpCode "echo get_option('siteurl');"
```

**Resultado esperado:**
- Devuelve URL del sitio (https://padel.wandori.us)

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-005: Ver Logs

```powershell
.\manager.ps1 logs -SiteName "padel" -Lines 20
.\manager.ps1 logs -SiteName "padel" -Target mariadb -Lines 20
```

**Resultado esperado:**
- Muestra ultimas 20 lineas de logs WordPress
- Muestra ultimas 20 lineas de logs MariaDB

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-006: Reiniciar Sitio

```powershell
.\manager.ps1 restart -SiteName "padel"
```

**Resultado esperado:**
- Reinicia contenedores del sitio
- Sitio vuelve a estado [OK] en unos segundos

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

#### TEST-007: Actualizar Tema (git pull)

```powershell
.\manager.ps1 deploy -SiteName "padel" -Update
```

**Resultado esperado:**
- Ejecuta git pull en tema Glory
- Ejecuta git pull en libreria Glory
- Ejecuta composer install
- Ejecuta npm run build (si aplica)

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

### 3.3 Test de Sitio Nuevo (Opcional - Destructivo)

#### TEST-008: Crear Nuevo Sitio

```powershell
# ADVERTENCIA: Crea recursos reales en Coolify
.\manager.ps1 new -SiteName "test-auto" -Domain "https://test.wandori.us" -SkipTheme
```

**Resultado esperado:**
- Crea stack en Coolify
- Genera credenciales
- Registra en settings.json
- NO instala tema (-SkipTheme)

**Estado:** [ ] Pendiente [ ] Pasado [ ] Fallido

---

## 4. Mejoras de Arquitectura (SOLID)

### 4.1 Single Responsibility Principle (SRP)

**Problema actual:** `WordPressManager.psm1` hace demasiadas cosas

**Solucion propuesta:**
```
modules/
├── CoolifyApi.psm1      # (OK) Solo API Coolify
├── SshOperations.psm1   # (OK) Solo SSH/Docker
├── WordPress/
│   ├── ThemeManager.psm1     # Gestion de temas
│   ├── DatabaseManager.psm1  # Importar/exportar BD
│   └── UserManager.psm1      # Crear/gestionar usuarios
└── Config/
    ├── ConfigLoader.psm1     # Cargar configuracion
    └── ConfigValidator.psm1  # Validar configuracion
```

### 4.2 Open/Closed Principle (OCP)

**Problema:** Agregar nuevos comandos requiere modificar `manager.ps1`

**Solucion:** Registro dinamico de comandos
```powershell
# Nuevo archivo: commands/registry.ps1
$CommandRegistry = @{
    "new"     = @{ Script = "new-site.ps1"; Description = "Crear sitio" }
    "list"    = @{ Script = "list-sites.ps1"; Description = "Listar sitios" }
    # Agregar nuevos comandos aqui sin modificar manager.ps1
}
```

### 4.3 Dependency Inversion Principle (DIP)

**Problema:** Modulos dependen directamente de rutas hardcodeadas

**Solucion:** Inyectar configuracion
```powershell
# En lugar de:
$script:ConfigPath = Join-Path $ModuleRoot "config\\settings.json"

# Usar:
function Initialize-Module {
    param([string]$ConfigPath)
    $script:Config = Get-Content $ConfigPath | ConvertFrom-Json
}
```

---

## 5. Mejoras de Seguridad

### 5.1 Proteger Credenciales

**Problema:** Token API visible en `settings.json`

**Opciones:**
1. **Variables de entorno** (Recomendado)
2. Windows Credential Manager
3. Archivo separado con .gitignore

**Implementacion:**
```powershell
# Nuevo: config/settings.template.json (sin datos sensibles)
# Usuario crea: config/settings.local.json (en .gitignore)
# O usa: $env:COOLIFY_API_TOKEN
```

### 5.2 Corregir Password Hardcodeado

**Archivo:** `WordPressManager.psm1` linea 236

**Antes:**
```powershell
$importCmd = "mariadb -u manager -ppassword $DbName < /tmp/import.sql"
```

**Despues:**
```powershell
$dbPassword = Get-DbPassword -StackName $StackName
$importCmd = "mariadb -u manager -p'$dbPassword' $DbName < /tmp/import.sql"
```

---

## 6. Mejoras de Logging

### 6.1 Sistema de Logs Estructurado

```powershell
# Nuevo modulo: modules/Logger.psm1

enum LogLevel {
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
}

function Write-Log {
    param(
        [LogLevel]$Level,
        [string]$Message,
        [string]$Command = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Consola con colores
    $color = switch ($Level) {
        "DEBUG" { "Gray" }
        "INFO"  { "White" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host $logEntry -ForegroundColor $color
    
    # Archivo (opcional)
    $logFile = Join-Path $PSScriptRoot "..\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logEntry
}
```

---

## 7. Validacion de Entradas

### 7.1 Validador de Sitios

```powershell
# Nuevo: modules/Validators.psm1

function Test-SiteExists {
    param([string]$SiteName)
    
    $config = Get-CoolifyConfig
    $site = $config.sitios | Where-Object { $_.nombre -eq $SiteName }
    
    if (-not $site) {
        throw "Sitio '$SiteName' no encontrado. Sitios disponibles: $($config.sitios.nombre -join ', ')"
    }
    
    return $site
}

function Test-DomainFormat {
    param([string]$Domain)
    
    if ($Domain -notmatch '^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        throw "Formato de dominio invalido. Usar: https://ejemplo.com"
    }
    
    return $true
}
```

---

## 8. Tests Automatizados (Fase 2)

### 8.1 Estructura de Tests

```
coolify-manager/
├── tests/
│   ├── Unit/
│   │   ├── CoolifyApi.Tests.ps1
│   │   ├── SshOperations.Tests.ps1
│   │   └── Validators.Tests.ps1
│   ├── Integration/
│   │   ├── CreateSite.Tests.ps1
│   │   └── DeployTheme.Tests.ps1
│   └── Mocks/
│       ├── MockSsh.psm1
│       └── MockApi.psm1
└── ...
```

### 8.2 Ejemplo de Test Unitario (Pester)

```powershell
# tests/Unit/Validators.Tests.ps1
Describe "Test-DomainFormat" {
    It "Acepta dominio HTTPS valido" {
        Test-DomainFormat -Domain "https://mi-sitio.com" | Should -Be $true
    }
    
    It "Rechaza dominio sin protocolo" {
        { Test-DomainFormat -Domain "mi-sitio.com" } | Should -Throw
    }
    
    It "Rechaza dominio con espacios" {
        { Test-DomainFormat -Domain "https://mi sitio.com" } | Should -Throw
    }
}
```

### 8.3 Ejecutar Tests

```powershell
# Instalar Pester (una vez)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Ejecutar todos los tests
Invoke-Pester -Path ".\tests" -Output Detailed
```

---

## 9. Roadmap de Implementacion

### Semana 1: Validacion y Correccion

| Dia | Tarea                                         |
| --- | --------------------------------------------- |
| 1   | Ejecutar tests manuales (TEST-001 a TEST-007) |
| 2   | Corregir bugs encontrados                     |
| 3   | Implementar validacion de entradas            |
| 4   | Corregir password hardcodeado                 |
| 5   | Implementar sistema de logs basico            |

### Semana 2: Tests Automatizados

| Dia | Tarea                                          |
| --- | ---------------------------------------------- |
| 1   | Configurar Pester                              |
| 2   | Tests unitarios para Validators                |
| 3   | Tests unitarios para CoolifyApi (con mocks)    |
| 4   | Tests unitarios para SshOperations (con mocks) |
| 5   | Documentar cobertura                           |

### Semana 3: Refactorizacion

| Dia | Tarea                                  |
| --- | -------------------------------------- |
| 1   | Dividir WordPressManager en submodulos |
| 2   | Implementar registro de comandos       |
| 3   | Externalizar configuracion sensible    |
| 4   | Actualizar documentacion               |
| 5   | Revision final y release v1.1.0        |

---

## 10. Metricas de Exito

### Calidad

- [ ] 100% tests manuales pasando
- [ ] 80%+ cobertura en tests unitarios
- [ ] 0 passwords/tokens en codigo

### Mantenibilidad

- [ ] Ningun archivo > 300 lineas
- [ ] Cada modulo tiene UNA responsabilidad
- [ ] Documentacion actualizada

### Escalabilidad

- [ ] Agregar nuevo comando sin modificar manager.ps1
- [ ] Agregar nuevo sitio sin modificar codigo
- [ ] Configuracion externalizada

---

## 11. Proximos Pasos Inmediatos

1. **EJECUTAR TEST-001** - Verificar conexion SSH
2. **EJECUTAR TEST-002** - Verificar listado de sitios
3. **Documentar resultados** - Actualizar este archivo
4. **Crear primer test automatizado** - Validadores

---

*Documento generado automaticamente. Actualizar segun avance del proyecto.*
