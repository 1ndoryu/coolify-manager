# Arquitectura - Coolify Manager v2.0

**Documento:** Guia de Arquitectura Tecnica  
**Fecha de creacion:** 2026-01-06  
**Ultima actualizacion:** 2026-01-06  
**Estado:** Produccion

---

## Tabla de Contenidos

1. [Vision General](#1-vision-general)
2. [Estructura de Carpetas](#2-estructura-de-carpetas)
3. [Modulos](#3-modulos)
4. [Flujo de Datos](#4-flujo-de-datos)
5. [Principios SOLID](#5-principios-solid)
6. [Convenciones de Codigo](#6-convenciones-de-codigo)
7. [Guia de Extension](#7-guia-de-extension)

---

## 1. Vision General

Coolify Manager es una herramienta de automatizacion para gestionar sitios WordPress desplegados en Coolify. La arquitectura sigue los principios SOLID y esta diseñada para ser:

- **Modular**: Cada modulo tiene una responsabilidad unica
- **Testeable**: Todos los modulos tienen tests unitarios
- **Extensible**: Nuevos comandos se agregan sin modificar codigo existente
- **Segura**: Credenciales externalizadas via variables de entorno

---

## 2. Estructura de Carpetas

```
coolify-manager/
├── manager.ps1              # Punto de entrada principal
├── config/
│   ├── settings.json        # Configuracion (con datos sensibles)
│   └── settings.template.json # Template para nuevas instalaciones
├── modules/
│   ├── Core/                # Modulos fundamentales
│   │   ├── ConfigManager.psm1   # Gestion de configuracion
│   │   ├── Logger.psm1          # Sistema de logs
│   │   └── Validators.psm1      # Validaciones de input
│   ├── WordPress/           # Modulos de WordPress (SOLID)
│   │   ├── ThemeManager.psm1    # Gestion del tema Glory
│   │   ├── DatabaseManager.psm1 # Operaciones de BD
│   │   └── SiteManager.psm1     # Configuracion de sitio
│   ├── CoolifyApi.psm1      # Cliente API de Coolify
│   ├── SshOperations.psm1   # Operaciones SSH/Docker
│   └── WordPressManager.psm1 # FACADE (compatibilidad hacia atras)
├── commands/
│   ├── registry.psm1        # Registro dinamico de comandos
│   ├── new-site.ps1         # Crear sitio
│   ├── list-sites.ps1       # Listar sitios
│   ├── restart-site.ps1     # Reiniciar sitio
│   ├── deploy-theme.ps1     # Desplegar tema
│   ├── import-database.ps1  # Importar BD
│   ├── exec-command.ps1     # Ejecutar comando en contenedor
│   └── view-logs.ps1        # Ver logs
├── templates/
│   └── wordpress-stack.yaml # Docker Compose template
├── tests/
│   ├── Unit/                # Tests unitarios (Pester)
│   │   ├── Validators.Tests.ps1
│   │   ├── ConfigManager.Tests.ps1
│   │   └── Logger.Tests.ps1
│   ├── Integration/         # Tests de integracion
│   │   ├── ThemeManager.Tests.ps1
│   │   ├── DatabaseManager.Tests.ps1
│   │   └── SiteManager.Tests.ps1
│   ├── Test-Manual.ps1      # Tests manuales completos
│   └── Test-Ssh.ps1         # Tests de conectividad SSH
├── logs/                    # Directorio de logs
└── docs/
    ├── PLAN-MAESTRO.md      # Plan de desarrollo
    ├── ARQUITECTURA.md      # Este documento
    └── CHANGELOG.md         # Historial de cambios
```

---

## 3. Modulos

### 3.1 Core/ConfigManager.psm1

**Responsabilidad**: Gestion centralizada de configuracion

**Funciones exportadas**:
- `Get-Config` - Obtiene toda la configuracion
- `Get-SiteConfig` - Obtiene config de un sitio especifico
- `Get-VpsConfig` - Obtiene config del VPS
- `Get-CoolifyConfig` - Obtiene config de Coolify
- `Get-AllSites` - Lista todos los sitios
- `Get-DbPassword` - Obtiene password de BD de forma segura

**Caracteristicas**:
- Soporte para variables de entorno `${VAR_NAME}`
- Cache de configuracion para rendimiento
- Busqueda segura de credenciales

### 3.2 Core/Logger.psm1

**Responsabilidad**: Logging estructurado

**Funciones exportadas**:
- `Write-Log` - Escribe entrada de log
- `Get-LogEntries` - Lee entradas de log
- `Clear-OldLogs` - Limpia logs antiguos
- `Get-LogPath` - Obtiene ruta del log actual

**Niveles de log**:
- DEBUG - Solo en modo verbose
- INFO - Operaciones normales
- WARN - Problemas no criticos
- ERROR - Errores que requieren atencion

### 3.3 Core/Validators.psm1

**Responsabilidad**: Validacion de inputs y estados

**Funciones exportadas**:
- `Test-SiteExists` - Verifica si un sitio existe
- `Test-DomainFormat` - Valida formato de dominio
- `Test-StackUuidExists` - Verifica UUID de stack
- `Test-SshConnection` - Prueba conexion SSH
- `Test-CoolifyApiConnection` - Prueba API
- `Test-SqlFileExists` - Valida archivo SQL
- `Assert-SiteReady` - Validacion compuesta

### 3.4 WordPress/ThemeManager.psm1

**Responsabilidad**: Gestion del tema Glory

**Funciones exportadas**:
- `Get-GloryConfig` - Obtiene config de repositorios
- `Install-GloryTheme` - Instalacion completa
- `Update-GloryTheme` - Actualizacion via git pull

### 3.5 WordPress/DatabaseManager.psm1

**Responsabilidad**: Operaciones de base de datos

**Funciones exportadas**:
- `Import-WordPressDatabase` - Importa archivo SQL
- `Export-WordPressDatabase` - Exporta BD a archivo

### 3.6 WordPress/SiteManager.psm1

**Responsabilidad**: Configuracion de sitios WordPress

**Funciones exportadas**:
- `Get-SiteConfig` - Obtiene config de sitio
- `Set-WordPressUrls` - Actualiza URLs
- `New-WordPressAdmin` - Crea usuario admin
- `Get-WordPressOption` - Lee opciones de WP

### 3.7 WordPressManager.psm1 (FACADE)

**Responsabilidad**: Compatibilidad hacia atras

Este modulo actua como un **facade** que re-exporta todas las funciones
de los modulos WordPress/*. Permite que codigo existente que importa
`WordPressManager.psm1` siga funcionando sin cambios.

---

## 4. Flujo de Datos

```
┌─────────────────┐
│   manager.ps1   │  ← Punto de entrada
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   commands/     │  ← Comandos especificos
│   *.ps1         │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────────┐
│ Core/  │ │ WordPress/ │  ← Modulos de negocio
└────────┘ └────────────┘
    │              │
    └──────┬───────┘
           ▼
┌─────────────────────────┐
│   CoolifyApi.psm1       │  ← API de Coolify
│   SshOperations.psm1    │  ← SSH + Docker
└─────────────────────────┘
           │
           ▼
┌─────────────────────────┐
│   VPS + Docker          │  ← Infraestructura
│   Coolify               │
└─────────────────────────┘
```

---

## 5. Principios SOLID

### Single Responsibility (S)

Cada modulo tiene una unica responsabilidad:
- `ThemeManager` → Solo temas
- `DatabaseManager` → Solo BD
- `SiteManager` → Solo config de sitio

### Open/Closed (O)

Nuevos comandos se agregan en `commands/` sin modificar `manager.ps1`.
El registro dinamico (`registry.psm1`) descubre comandos automaticamente.

### Liskov Substitution (L)

Los modulos WordPress/* pueden sustituirse sin afectar el facade.

### Interface Segregation (I)

Los comandos solo importan los modulos que necesitan.
No se pasan objetos de config completos a funciones que solo necesitan 1-2 propiedades.

### Dependency Inversion (D)

Los modulos dependen de abstracciones (interfaces de config) no de implementaciones concretas.
Las credenciales se inyectan via ConfigManager, no hardcodeadas.

---

## 6. Convenciones de Codigo

### Nomenclatura

- **Variables/Funciones**: `camelCase`
- **Modulos/Clases**: `PascalCase`
- **Archivos**: `kebab-case.ps1` para comandos, `PascalCase.psm1` para modulos

### Documentacion

Cada funcion debe tener:
```powershell
<#
.SYNOPSIS
    Breve descripcion de una linea
.DESCRIPTION
    Descripcion detallada (opcional)
.PARAMETER NombreParam
    Descripcion del parametro
.EXAMPLE
    Ejemplo de uso
#>
```

### Logging

Usar `Write-Log` para todo registro:
```powershell
Write-Log -Level INFO -Message "Operacion exitosa" -Command "NombreFuncion"
```

### Validacion

Validar todos los inputs al inicio de cada funcion:
```powershell
$site = Assert-SiteReady -SiteName $SiteName -RequireUuid
```

---

## 7. Guia de Extension

### Agregar un Nuevo Comando

1. Crear archivo `commands/mi-comando.ps1`:

```powershell
<#
.SYNOPSIS
    Mi nuevo comando
.PARAMETER SiteName
    Nombre del sitio
#>
param(
    [Parameter(Mandatory)]
    [string]$SiteName
)

$ModulesPath = Join-Path $PSScriptRoot "..\modules"
Import-Module (Join-Path $ModulesPath "Core\Validators.psm1") -Force
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force

# Validar
$sitio = Assert-SiteReady -SiteName $SiteName -RequireUuid

# Logica del comando
Write-Log -Level INFO -Message "Ejecutando mi-comando" -Command "mi-comando"

# ...
```

2. (Opcional) Crear metadatos `commands/mi-comando.json`:

```json
{
    "description": "Descripcion corta del comando",
    "category": "general",
    "examples": [
        ".\\manager.ps1 mi-comando -SiteName padel"
    ]
}
```

3. El comando estara disponible automaticamente via el registro dinamico.

### Agregar un Nuevo Modulo

1. Crear archivo en la carpeta apropiada (`Core/`, `WordPress/`, etc.)
2. Exportar funciones con `Export-ModuleMember`
3. Crear tests en `tests/Unit/` o `tests/Integration/`
4. Actualizar este documento si es un modulo importante

---

*Arquitectura v2.0 - Generado el 2026-01-06*
