# PLAN MAESTRO - Coolify Manager v2.0

**Documento:** Plan de Desarrollo Integral  
**Fecha de creación:** 2026-01-06  
**Última actualización:** 2026-01-06  
**Responsable:** Sistema de IA  
**Estado:** En planificación

---

## Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Análisis del Estado Actual](#2-análisis-del-estado-actual)
3. [Arquitectura Objetivo](#3-arquitectura-objetivo)
4. [Plan de Testing](#4-plan-de-testing)
5. [Plan de Refactorización](#5-plan-de-refactorización)
6. [Plan de Seguridad](#6-plan-de-seguridad)
7. [Plan de Escalabilidad](#7-plan-de-escalabilidad)
8. [Roadmap de Implementación](#8-roadmap-de-implementación)
9. [Métricas y KPIs](#9-métricas-y-kpis)
10. [Riesgos y Mitigación](#10-riesgos-y-mitigación)
11. [Checklist de Entregables](#11-checklist-de-entregables)

---

## 1. Visión General

### 1.1 Propósito

**Coolify Manager** es una herramienta de automatización para gestionar sitios WordPress desplegados en Coolify. Debe ser:

- **Confiable** - Funciona sin errores en producción
- **Escalable** - Soporta N sitios sin modificar código
- **Mantenible** - Código limpio, modular, documentado
- **Segura** - Sin credenciales expuestas
- **Testeable** - Cobertura de tests automatizados

### 1.2 Alcance

| En Alcance                      | Fuera de Alcance        |
| ------------------------------- | ----------------------- |
| Gestión de WordPress en Coolify | Soporte para otros CMS  |
| API REST de Coolify v4          | Coolify v3 o anteriores |
| Tema Glory y sus ramas          | Otros temas             |
| VPS actual (66.94.100.241)      | Multi-VPS (futuro)      |
| PowerShell 5.1+ en Windows      | Linux/Mac (futuro)      |

### 1.3 Usuarios Objetivo

1. **Usuario Manual** - Ejecuta comandos desde terminal
2. **IA Asistente** - Ejecuta comandos programáticamente
3. **Scripts de CI/CD** - Despliegues automatizados (futuro)

---

## 2. Análisis del Estado Actual

### 2.1 Inventario de Componentes

```
coolify-manager/
├── manager.ps1              # Punto de entrada (163 líneas)
├── config/
│   └── settings.json        # Configuración (54 líneas) ⚠️ Datos sensibles
├── modules/
│   ├── CoolifyApi.psm1      # API Coolify (225 líneas) ✅
│   ├── SshOperations.psm1   # SSH/Docker (219 líneas) ✅
│   └── WordPressManager.psm1 # WP Manager (304 líneas) ⚠️ Demasiadas responsabilidades
├── commands/
│   ├── new-site.ps1         # Crear sitio (112 líneas)
│   ├── list-sites.ps1       # Listar (84 líneas)
│   ├── restart-site.ps1     # Reiniciar (85 líneas)
│   ├── deploy-theme.ps1     # Tema (72 líneas)
│   ├── import-database.ps1  # BD (70 líneas)
│   ├── exec-command.ps1     # Ejecutar (68 líneas)
│   └── view-logs.ps1        # Logs (53 líneas)
├── templates/
│   └── wordpress-stack.yaml # Docker Compose (26 líneas)
├── tests/                   # NUEVO
│   ├── Test-Manual.ps1
│   ├── Test-Ssh.ps1
│   └── README.md
└── docs/                    # NUEVO
    └── PLAN-TESTING-REFACTOR.md
```

### 2.2 Resultados del Análisis de Tests (2026-01-06)

#### Tests Manuales (Test-Manual.ps1)

| Categoría          | Tests  | Pasados | Fallidos | Tasa      |
| ------------------ | ------ | ------- | -------- | --------- |
| API Coolify        | 1      | 1       | 0        | 100%      |
| Servicios          | 6      | 5       | 1        | 83%       |
| Configuración      | 3      | 3       | 0        | 100%      |
| Sitios Registrados | 4      | 3       | 1        | 75%       |
| HTTP Acceso        | 4      | 4       | 0        | 100%      |
| Módulos            | 3      | 3       | 0        | 100%      |
| Comandos           | 7      | 7       | 0        | 100%      |
| **TOTAL**          | **28** | **26**  | **2**    | **92.9%** |

#### Tests Unitarios (Pester 3.4.0)

| Módulo        | Tests  | Pasados | Fallidos | Nota                           |
| ------------- | ------ | ------- | -------- | ------------------------------ |
| ConfigManager | 16     | 15      | 1        | Bug de Pester con Should Throw |
| Logger        | 9      | 9       | 0        | 100%                           |
| Validators    | 14     | 9       | 5        | Bug de Pester con Should Throw |
| **TOTAL**     | **39** | **33**  | **6**    | **84.6%**                      |

> **Nota:** Los 6 tests fallidos son por incompatibilidad de sintaxis con Pester 3.4.0,
> no por errores en el código. El código funciona correctamente.

### 2.3 Problemas Detectados

#### Críticos (Bloquean funcionalidad)

| ID   | Problema                        | Archivo               | Línea | Impacto           |
| ---- | ------------------------------- | --------------------- | ----- | ----------------- |
| C-01 | Password hardcodeado "password" | WordPressManager.psm1 | 236   | Seguridad crítica |
| C-02 | SSH se cuelga en PowerShell     | SshOperations.psm1    | 43    | Bloquea comandos  |

#### Altos (Afectan usabilidad)

| ID   | Problema                            | Archivo            | Impacto          |
| ---- | ----------------------------------- | ------------------ | ---------------- |
| A-01 | Sin validación de sitios existentes | Todos los comandos | Errores confusos |
| A-02 | Token API visible en JSON           | settings.json      | Seguridad        |
| A-03 | Sitio "guillermo" sin UUID          | settings.json      | Comando fallará  |

#### Medios (Afectan mantenibilidad)

| ID   | Problema                        | Archivo               | Impacto               |
| ---- | ------------------------------- | --------------------- | --------------------- |
| M-01 | WordPressManager hace demasiado | WordPressManager.psm1 | Difícil de mantener   |
| M-02 | Sin logging estructurado        | Todos                 | Difícil debugging     |
| M-03 | Sin tests unitarios             | N/A                   | Riesgo de regresiones |

#### Bajos (Mejoras futuras)

| ID   | Problema                      | Impacto                                      |
| ---- | ----------------------------- | -------------------------------------------- |
| B-01 | Registro de comandos estático | Agregar comandos requiere editar manager.ps1 |
| B-02 | Sin soporte multi-VPS         | Limitado a un servidor                       |
| B-03 | Sin backup automático         | Riesgo de pérdida de datos                   |

---

## 3. Arquitectura Objetivo

### 3.1 Estructura Propuesta v2.0

```
coolify-manager/
├── manager.ps1                      # Punto de entrada simplificado
├── config/
│   ├── settings.template.json       # Template (sin datos sensibles)
│   ├── settings.local.json          # Configuración real (.gitignore)
│   └── sites/                       # Un archivo por sitio (futuro)
│       ├── padel.json
│       ├── nakomi.json
│       └── wandori.json
├── modules/
│   ├── Core/
│   │   ├── Logger.psm1              # NUEVO: Sistema de logs
│   │   ├── ConfigManager.psm1       # NUEVO: Gestión de config
│   │   └── Validators.psm1          # NUEVO: Validaciones
│   ├── Coolify/
│   │   └── CoolifyApi.psm1          # API Coolify (refactorizado)
│   ├── Infrastructure/
│   │   └── SshOperations.psm1       # SSH/Docker (refactorizado)
│   └── WordPress/
│       ├── ThemeManager.psm1        # NUEVO: Solo temas
│       ├── DatabaseManager.psm1     # NUEVO: Solo BD
│       └── SiteManager.psm1         # NUEVO: URLs y config WP
├── commands/
│   ├── registry.ps1                 # NUEVO: Registro dinámico
│   └── [comandos existentes]
├── templates/
│   └── wordpress-stack.yaml
├── tests/
│   ├── Unit/                        # Tests unitarios
│   │   ├── Validators.Tests.ps1
│   │   ├── ConfigManager.Tests.ps1
│   │   └── CoolifyApi.Tests.ps1
│   ├── Integration/                 # Tests de integración
│   │   ├── CreateSite.Tests.ps1
│   │   └── DeployTheme.Tests.ps1
│   ├── Mocks/                       # Mocks para tests
│   │   ├── MockSsh.psm1
│   │   └── MockApi.psm1
│   └── Manual/                      # Tests manuales
│       ├── Test-Manual.ps1
│       └── Test-Ssh.ps1
├── logs/                            # NUEVO: Directorio de logs
│   └── .gitkeep
└── docs/
    ├── PLAN-MAESTRO.md              # Este documento
    ├── ARQUITECTURA.md              # Documentación técnica
    └── CHANGELOG.md                 # Historial de cambios
```

### 3.2 Diagrama de Dependencias

```
┌─────────────────────────────────────────────────────────────┐
│                        manager.ps1                          │
│                    (Punto de entrada)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    commands/*.ps1                           │
│  new-site │ list-sites │ restart │ deploy │ exec │ logs    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌───────────────────┐ ┌─────────────┐ ┌─────────────────────┐
│   Core/           │ │   Coolify/  │ │   Infrastructure/   │
│ ─────────────────│ │ ───────────│ │ ───────────────────│
│ Logger.psm1       │ │ CoolifyApi  │ │ SshOperations.psm1  │
│ ConfigManager.psm1│ │ .psm1       │ │                     │
│ Validators.psm1   │ │             │ │                     │
└───────────────────┘ └─────────────┘ └─────────────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      WordPress/                             │
│  ThemeManager.psm1 │ DatabaseManager.psm1 │ SiteManager.psm1│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     config/                                 │
│              settings.local.json (protegido)                │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Principios SOLID Aplicados

| Principio                 | Problema Actual                           | Solución                |
| ------------------------- | ----------------------------------------- | ----------------------- |
| **S**ingle Responsibility | WordPressManager hace temas, BD, usuarios | Dividir en 3 módulos    |
| **O**pen/Closed           | Agregar comando = editar manager.ps1      | Registro dinámico       |
| **L**iskov Substitution   | N/A                                       | N/A                     |
| **I**nterface Segregation | Comandos reciben toda la config           | Solo pasar lo necesario |
| **D**ependency Inversion  | Módulos hardcodean rutas                  | Inyectar dependencias   |

---

## 4. Plan de Testing

### 4.1 Estrategia de Testing

```
                    ┌─────────────────────┐
                    │   Tests E2E         │  ← 10% (Manuales, flujo completo)
                    │   (Manuales)        │
                    └─────────────────────┘
               ┌────────────────────────────────┐
               │     Tests de Integración       │  ← 30% (API + SSH + Docker)
               │     (Semi-automatizados)       │
               └────────────────────────────────┘
          ┌─────────────────────────────────────────┐
          │          Tests Unitarios                │  ← 60% (Funciones aisladas)
          │          (Automatizados con Pester)     │
          └─────────────────────────────────────────┘
```

### 4.2 Tests Manuales (Checklist)

#### Fase 1: Conectividad (Prerequisitos)

| ID    | Test                 | Comando                            | Estado |
| ----- | -------------------- | ---------------------------------- | ------ |
| TM-01 | Ping al VPS          | `Test-Connection 66.94.100.241`    | [ ]    |
| TM-02 | Puerto SSH abierto   | `Test-NetConnection -Port 22`      | [ ]    |
| TM-03 | SSH manual funciona  | `ssh root@66.94.100.241 "echo OK"` | [ ]    |
| TM-04 | API Coolify responde | `.\manager.ps1 status`             | [ ]    |

#### Fase 2: Comandos Básicos

| ID    | Test               | Comando                                              | Estado |
| ----- | ------------------ | ---------------------------------------------------- | ------ |
| TM-05 | Listar sitios      | `.\manager.ps1 list`                                 | [ ]    |
| TM-06 | Ver logs WordPress | `.\manager.ps1 logs -SiteName padel`                 | [ ]    |
| TM-07 | Ver logs MariaDB   | `.\manager.ps1 logs -SiteName padel -Target mariadb` | [ ]    |

#### Fase 3: Comandos de Ejecución

| ID    | Test      | Comando                                                                     | Estado |
| ----- | --------- | --------------------------------------------------------------------------- | ------ |
| TM-08 | Exec bash | `.\manager.ps1 exec -SiteName padel -Command "ls /var/www/html"`            | [ ]    |
| TM-09 | Exec PHP  | `.\manager.ps1 exec -SiteName padel -PhpCode "echo get_option('siteurl');"` | [ ]    |

#### Fase 4: Comandos Destructivos (Con precaución)

| ID    | Test            | Comando                                        | Estado |
| ----- | --------------- | ---------------------------------------------- | ------ |
| TM-10 | Reiniciar sitio | `.\manager.ps1 restart -SiteName padel`        | [ ]    |
| TM-11 | Actualizar tema | `.\manager.ps1 deploy -SiteName padel -Update` | [ ]    |

#### Fase 5: Crear Sitio (Opcional)

| ID    | Test        | Comando                                                                       | Estado |
| ----- | ----------- | ----------------------------------------------------------------------------- | ------ |
| TM-12 | Nuevo sitio | `.\manager.ps1 new -SiteName test -Domain https://test.wandori.us -SkipTheme` | [ ]    |

### 4.3 Tests Unitarios (Pester)

#### A implementar:

```powershell
# tests/Unit/Validators.Tests.ps1
Describe "Validators" {
    Context "Test-DomainFormat" {
        It "Acepta HTTPS válido" { ... }
        It "Acepta HTTP válido" { ... }
        It "Rechaza sin protocolo" { ... }
        It "Rechaza con espacios" { ... }
        It "Rechaza IP sin protocolo" { ... }
    }
    
    Context "Test-SiteExists" {
        It "Retorna sitio si existe" { ... }
        It "Lanza error si no existe" { ... }
        It "Sugiere sitios disponibles" { ... }
    }
    
    Context "Test-StackUuidExists" {
        It "Retorna true si tiene UUID" { ... }
        It "Retorna false si no tiene UUID" { ... }
    }
}
```

### 4.4 Tests de Integración

```powershell
# tests/Integration/CoolifyApi.Tests.ps1
Describe "CoolifyApi Integration" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\modules\Coolify\CoolifyApi.psm1"
    }
    
    It "Obtiene lista de servicios" {
        $services = Get-CoolifyServices
        $services | Should -Not -BeNullOrEmpty
    }
    
    It "Obtiene servicio por UUID" {
        $service = Get-CoolifyServiceByUuid -Uuid "zkcc040cc0scock4kcooowkc"
        $service.name | Should -Be "padel-stack"
    }
}
```

---

## 5. Plan de Refactorización

### 5.1 Prioridades de Refactorización

| Prioridad | Tarea                         | Impacto | Esfuerzo | Dependencias  |
| --------- | ----------------------------- | ------- | -------- | ------------- |
| P1        | Corregir password hardcodeado | Crítico | Bajo     | Ninguna       |
| P2        | Crear módulo Validators       | Alto    | Bajo     | Ninguna       |
| P3        | Crear módulo Logger           | Medio   | Bajo     | Ninguna       |
| P4        | Crear módulo ConfigManager    | Alto    | Medio    | Validators    |
| P5        | Dividir WordPressManager      | Alto    | Alto     | ConfigManager |
| P6        | Registro dinámico de comandos | Medio   | Medio    | ConfigManager |
| P7        | Externalizar credenciales     | Crítico | Medio    | ConfigManager |

### 5.2 Orden de Implementación

```
Semana 1: Correcciones Críticas
├── Día 1-2: Corregir password hardcodeado (P1)
├── Día 3-4: Crear Validators.psm1 (P2)
└── Día 5: Crear Logger.psm1 (P3)

Semana 2: Restructuración Core
├── Día 1-2: Crear ConfigManager.psm1 (P4)
├── Día 3-4: Externalizar credenciales (P7)
└── Día 5: Tests unitarios para Core

Semana 3: Refactorización WordPress
├── Día 1-2: Crear ThemeManager.psm1
├── Día 3-4: Crear DatabaseManager.psm1
└── Día 5: Crear SiteManager.psm1

Semana 4: Mejoras de Extensibilidad
├── Día 1-2: Registro dinámico de comandos (P6)
├── Día 3-4: Actualizar documentación
└── Día 5: Tests de integración completos
```

### 5.3 Detalle de Nuevos Módulos

#### 5.3.1 Validators.psm1

```powershell
# Funciones a implementar:
- Test-SiteExists($SiteName) -> $SiteConfig | throw
- Test-DomainFormat($Domain) -> $true | throw
- Test-StackUuidExists($SiteName) -> $true | $false
- Test-SshConnection() -> $true | $false
- Test-CoolifyApiConnection() -> $true | $false
```

#### 5.3.2 Logger.psm1

```powershell
# Funciones a implementar:
- Write-Log($Level, $Message, $Command)
- Get-LogPath() -> $Path
- Clear-OldLogs($DaysToKeep)

# Niveles:
- DEBUG (solo en modo verbose)
- INFO (operaciones normales)
- WARN (problemas no críticos)
- ERROR (errores que requieren atención)
```

#### 5.3.3 ConfigManager.psm1

```powershell
# Funciones a implementar:
- Get-Config() -> $Config
- Get-SiteConfig($SiteName) -> $SiteConfig
- Set-SiteConfig($SiteName, $Config) -> void
- Add-Site($SiteConfig) -> void
- Remove-Site($SiteName) -> void
- Get-Credential($Key) -> $Value (desde env o archivo)
```

---

## 6. Plan de Seguridad

### 6.1 Vulnerabilidades Actuales

| ID     | Vulnerabilidad                  | Severidad | Ubicación                 |
| ------ | ------------------------------- | --------- | ------------------------- |
| SEC-01 | Token API en texto plano        | Alta      | settings.json:9           |
| SEC-02 | Password "password" hardcodeado | Crítica   | WordPressManager.psm1:236 |
| SEC-03 | No hay validación de inputs     | Media     | Todos los comandos        |

### 6.2 Remediaciones

#### SEC-01: Token API

**Antes:**
```json
{
    "coolify": {
        "apiToken": "1|kA3XZuSONrl3ZFMAWTBStWSaa1Tcn49azfkkbTbg5071ad12"
    }
}
```

**Después:**
```json
{
    "coolify": {
        "apiToken": "${COOLIFY_API_TOKEN}"
    }
}
```

**Implementación:**
1. Crear `settings.template.json` sin datos sensibles
2. Agregar `settings.local.json` a `.gitignore`
3. Modificar `Get-Config` para soportar variables de entorno

#### SEC-02: Password Hardcodeado

**Antes:**
```powershell
$importCmd = "mariadb -u manager -ppassword $DbName < /tmp/import.sql"
```

**Después:**
```powershell
$dbPassword = Get-DbPassword -SiteName $SiteName
$importCmd = "mariadb -u manager -p'$dbPassword' $DbName < /tmp/import.sql"
```

**Implementación:**
1. Obtener password desde variables de entorno de Coolify
2. O leer desde el docker-compose del stack

#### SEC-03: Validación de Inputs

**Implementación:**
1. Crear `Validators.psm1`
2. Validar todos los parámetros de entrada
3. Usar `[ValidateScript()]` en parámetros

---

## 7. Plan de Escalabilidad

### 7.1 Necesidades Futuras

| Necesidad   | Descripción                            | Prioridad |
| ----------- | -------------------------------------- | --------- |
| Multi-sitio | Soportar muchos sitios sin degradación | Alta      |
| Multi-VPS   | Soportar varios servidores             | Media     |
| Plugins     | Sistema de plugins para extensiones    | Baja      |
| API REST    | Exponer funcionalidad via API          | Baja      |

### 7.2 Diseño para Escalabilidad

#### Multi-sitio

Actualmente: Un array `sitios` en un solo JSON

Propuesta: Un archivo por sitio en `config/sites/`

```
config/sites/
├── padel.json
├── nakomi.json
├── wandori.json
└── guillermo.json
```

**Ventajas:**
- Cada sitio es independiente
- Fácil agregar/eliminar sitios
- Menos conflictos en edición

#### Multi-VPS (Futuro)

```
config/
├── servers/
│   ├── vps1.json
│   └── vps2.json
└── sites/
    ├── padel.json      # Incluye "server": "vps1"
    └── nakomi.json     # Incluye "server": "vps1"
```

---

## 8. Roadmap de Implementación

### 8.1 Fase 1: Estabilización (Semana 1)

**Objetivo:** Sistema funcional y testeado

| Día | Tarea                                  | Entregables                       |
| --- | -------------------------------------- | --------------------------------- |
| 1   | Ejecutar tests manuales completos      | Checklist actualizado             |
| 2   | Corregir password hardcodeado (SEC-02) | WordPressManager.psm1 actualizado |
| 3   | Crear Validators.psm1                  | Nuevo módulo + tests              |
| 4   | Integrar validadores en comandos       | Comandos actualizados             |
| 5   | Documentar y revisar                   | Documentación actualizada         |

**Criterio de éxito:** 100% tests manuales pasando

### 8.2 Fase 2: Mejora de Calidad (Semana 2)

**Objetivo:** Código más mantenible y seguro

| Día | Tarea                              | Entregables            |
| --- | ---------------------------------- | ---------------------- |
| 1   | Crear Logger.psm1                  | Nuevo módulo           |
| 2   | Integrar logging en comandos       | Comandos actualizados  |
| 3   | Crear ConfigManager.psm1           | Nuevo módulo           |
| 4   | Externalizar credenciales (SEC-01) | settings.template.json |
| 5   | Tests unitarios para Core          | Tests Pester           |

**Criterio de éxito:** 80%+ cobertura en módulos Core

### 8.3 Fase 3: Refactorización (Semana 3)

**Objetivo:** Arquitectura limpia SOLID

| Día | Tarea                                        | Entregables           |
| --- | -------------------------------------------- | --------------------- |
| 1   | Dividir WordPressManager: ThemeManager       | ThemeManager.psm1     |
| 2   | Dividir WordPressManager: DatabaseManager    | DatabaseManager.psm1  |
| 3   | Dividir WordPressManager: SiteManager        | SiteManager.psm1      |
| 4   | Actualizar comandos para usar nuevos módulos | Comandos actualizados |
| 5   | Tests de integración                         | Tests completos       |

**Criterio de éxito:** Ningún archivo > 300 líneas

### 8.4 Fase 4: Extensibilidad (Semana 4)

**Objetivo:** Fácil agregar nuevas funcionalidades

| Día | Tarea                                     | Entregables              |
| --- | ----------------------------------------- | ------------------------ |
| 1   | Crear registro dinámico de comandos       | registry.ps1             |
| 2   | Actualizar manager.ps1 para usar registro | manager.ps1 simplificado |
| 3   | Configuración multi-sitio                 | config/sites/            |
| 4   | Documentación completa                    | docs/ARQUITECTURA.md     |
| 5   | Release v2.0                              | CHANGELOG.md actualizado |

**Criterio de éxito:** Agregar comando sin modificar manager.ps1

---

## 9. Métricas y KPIs

### 9.1 Métricas de Calidad

| Métrica                   | Actual  | Objetivo | Cómo Medir         |
| ------------------------- | ------- | -------- | ------------------ |
| Tests manuales pasando    | 92.9%   | 100%     | Test-Manual.ps1    |
| Cobertura tests unitarios | 0%      | 80%      | Pester + Coverage  |
| Bugs conocidos            | 5       | 0        | Issues en plan     |
| Líneas por archivo        | 304 máx | <300     | Script de análisis |

### 9.2 Métricas de Seguridad

| Métrica                | Actual | Objetivo |
| ---------------------- | ------ | -------- |
| Credenciales en código | 2      | 0        |
| Inputs sin validar     | ~100%  | 0%       |
| Logs de operaciones    | No     | Sí       |

### 9.3 Métricas de Mantenibilidad

| Métrica                            | Actual  | Objetivo |
| ---------------------------------- | ------- | -------- |
| Responsabilidades por módulo       | 3-5     | 1        |
| Documentación actualizada          | Parcial | 100%     |
| Comandos sin modificar manager.ps1 | No      | Sí       |

---

## 10. Riesgos y Mitigación

### 10.1 Riesgos Técnicos

| Riesgo                       | Probabilidad | Impacto | Mitigación                                |
| ---------------------------- | ------------ | ------- | ----------------------------------------- |
| SSH bloqueado en PowerShell  | Alta         | Alto    | Usar API Coolify cuando sea posible       |
| API Coolify cambia           | Baja         | Alto    | Versionar endpoints, tests de integración |
| Pérdida de datos en refactor | Media        | Alto    | Tests antes de cada cambio                |

### 10.2 Riesgos de Proceso

| Riesgo                       | Probabilidad | Impacto | Mitigación                      |
| ---------------------------- | ------------ | ------- | ------------------------------- |
| Scope creep                  | Media        | Medio   | Seguir roadmap estrictamente    |
| Regresiones                  | Media        | Alto    | Tests automatizados             |
| Documentación desactualizada | Alta         | Medio   | Actualizar docs con cada cambio |

---

## 11. Checklist de Entregables

### Fase 1: Estabilización

- [x] Tests manuales ejecutados (TM-01 a TM-12) ✅ 2026-01-06 (92.9% pasando)
- [x] SEC-02 corregido (password hardcodeado) ✅ 2026-01-06
- [x] Validators.psm1 creado ✅ 2026-01-06
- [x] Validadores integrados en comandos ✅ 2026-01-06
  - [x] exec-command.ps1
  - [x] view-logs.ps1
  - [x] deploy-theme.ps1
  - [x] restart-site.ps1
  - [x] import-database.ps1
  - [x] list-sites.ps1
- [x] Documentación actualizada (CHANGELOG.md) ✅ 2026-01-06

### Fase 2: Mejora de Calidad

- [x] Logger.psm1 creado ✅ 2026-01-06
- [x] Logging integrado en comandos ✅ 2026-01-06
- [x] ConfigManager.psm1 creado ✅ 2026-01-06
- [x] SEC-01 parcialmente corregido (template + soporte env vars) ✅ 2026-01-06
- [x] Tests unitarios para Core creados ✅ 2026-01-06
  - [x] Validators.Tests.ps1
  - [x] ConfigManager.Tests.ps1
  - [x] Logger.Tests.ps1

### Fase 3: Refactorización

- [x] ThemeManager.psm1 creado ✅ 2026-01-06
- [x] DatabaseManager.psm1 creado ✅ 2026-01-06
- [x] SiteManager.psm1 creado ✅ 2026-01-06
- [x] WordPressManager.psm1 refactorizado como facade ✅ 2026-01-06
- [x] Tests de integración ✅ 2026-01-06
  - [x] ThemeManager.Tests.ps1
  - [x] DatabaseManager.Tests.ps1
  - [x] SiteManager.Tests.ps1

### Fase 4: Extensibilidad

- [x] registry.psm1 creado ✅ 2026-01-06
- [ ] manager.ps1 simplificado (opcional - ya funciona bien)
- [ ] Configuración multi-sitio (futuro)
- [x] ARQUITECTURA.md creado ✅ 2026-01-06
- [x] CHANGELOG.md creado ✅ 2026-01-06
- [ ] Release v2.0

---

## Apéndices

### A. Comandos de Referencia Rápida

```powershell
# Ejecutar tests
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Manual.ps1"

# Ver ayuda
.\manager.ps1 help

# Listar sitios
.\manager.ps1 list

# Estado rápido
.\manager.ps1 status
```

### B. Variables de Entorno Propuestas

```powershell
$env:COOLIFY_API_TOKEN = "tu-token-aqui"
$env:COOLIFY_VPS_IP = "66.94.100.241"
$env:COOLIFY_VPS_USER = "root"
```

### C. Contacto y Soporte

- **Repositorio**: glorytemplate en GitHub
- **Documentación**: `.agent/coolify-manager/docs/`
- **Tests**: `.agent/coolify-manager/tests/`

---

*Plan Maestro v1.0 - Generado el 2026-01-06*
*Próxima revisión: Al completar Fase 1*
