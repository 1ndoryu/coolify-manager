# Changelog - Coolify Manager

Todos los cambios notables del proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased] - En desarrollo

### Agregado
- **Módulo `Validators.psm1`** - Sistema de validación centralizado
  - `Test-SiteExists` - Verifica si un sitio existe en la configuración
  - `Test-DomainFormat` - Valida formato de dominios (requiere protocolo)
  - `Test-StackUuidExists` - Verifica si un sitio tiene UUID configurado
  - `Test-SshConnection` - Prueba conectividad SSH al VPS
  - `Test-CoolifyApiConnection` - Prueba conectividad a la API de Coolify
  - `Test-SqlFileExists` - Valida existencia de archivos SQL
  - `Assert-SiteReady` - Validación compuesta para operaciones

- **Módulo `Logger.psm1`** - Sistema de logging estructurado
  - Niveles: DEBUG, INFO, WARN, ERROR
  - Rotación automática por fecha
  - Función `Write-Log` para registrar eventos
  - Función `Get-LogEntries` para consultar logs
  - Función `Clear-OldLogs` para limpieza automática

- **Módulo `ConfigManager.psm1`** - Gestión centralizada de configuración
  - Soporte para variables de entorno `${VAR_NAME}`
  - Cache de configuración para rendimiento
  - `Get-DbPassword` - Obtención segura de passwords
  - Operaciones CRUD para sitios

- **Estructura de carpetas mejorada**
  - `modules/Core/` - Módulos fundamentales
  - `modules/Coolify/` - (Preparado para refactorización)
  - `modules/Infrastructure/` - (Preparado para refactorización)
  - `modules/WordPress/` - (Preparado para refactorización)
  - `tests/Unit/` - Tests unitarios Pester
  - `tests/Integration/` - Tests de integración
  - `tests/Mocks/` - Mocks para testing
  - `logs/` - Directorio de logs

- **Tests unitarios Pester**
  - `Validators.Tests.ps1` - Tests para validadores
  - `ConfigManager.Tests.ps1` - Tests para gestión de config
  - `Logger.Tests.ps1` - Tests para sistema de logs

- **Template de configuración seguro**
  - `config/settings.template.json` - Sin datos sensibles

### Corregido
- **SEC-02 (CRÍTICO)**: Eliminado password hardcodeado "password" en `WordPressManager.psm1`
  - Ahora usa `Get-DbPassword` que busca en variables de entorno
  - Orden de búsqueda: `DB_PASSWORD_SITENAME` → `COOLIFY_DB_PASSWORD` → config file

### Seguridad
- Las credenciales ahora se pueden definir via variables de entorno
- Template de config sin datos sensibles para control de versiones
- Validación de inputs antes de operaciones críticas

---

## [1.0.0] - 2026-01-05

### Estado Inicial
- Punto de entrada `manager.ps1`
- Módulos: `CoolifyApi.psm1`, `SshOperations.psm1`, `WordPressManager.psm1`
- Comandos: new-site, list-sites, restart-site, deploy-theme, import-database, exec-command, view-logs
- Templates: wordpress-stack.yaml
- Tests manuales: Test-Manual.ps1, Test-Ssh.ps1

### Problemas Conocidos (En corrección)
- [x] SEC-02: Password hardcodeado (CORREGIDO)
- [ ] SEC-01: Token API en texto plano (En progreso)
- [ ] A-03: Sitio "guillermo" sin UUID
- [ ] M-01: WordPressManager con demasiadas responsabilidades

---

*Próxima versión planificada: v2.0.0 con arquitectura SOLID completa*
