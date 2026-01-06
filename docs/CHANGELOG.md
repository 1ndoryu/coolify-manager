# Changelog - Coolify Manager

Todos los cambios notables del proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased] - En desarrollo

### Agregado (Fase 3 - Refactorización SOLID)
- **Módulo `WordPress/ThemeManager.psm1`** - Gestión del tema Glory
  - `Get-GloryConfig` - Obtiene configuración de repositorios Glory
  - `Install-GloryTheme` - Instalación completa del tema con dependencias
  - `Update-GloryTheme` - Actualización via git pull + rebuild

- **Módulo `WordPress/DatabaseManager.psm1`** - Operaciones de base de datos
  - `Import-WordPressDatabase` - Importa archivos SQL a MariaDB
  - `Export-WordPressDatabase` - Exporta BD a archivo local (NUEVO)

- **Módulo `WordPress/SiteManager.psm1`** - Configuración de sitios WP
  - `Get-SiteConfig` - Obtiene config de sitio con mensaje de error mejorado
  - `Set-WordPressUrls` - Actualiza opciones home y siteurl
  - `New-WordPressAdmin` - Crea usuarios administradores
  - `Get-WordPressOption` - Obtiene cualquier opción de WP (NUEVO)

- **Tests de integración**
  - `tests/Integration/ThemeManager.Tests.ps1`
  - `tests/Integration/DatabaseManager.Tests.ps1`
  - `tests/Integration/SiteManager.Tests.ps1`

### Modificado
- **`WordPressManager.psm1`** refactorizado como módulo facade
  - Ahora re-exporta funciones de los módulos especializados
  - Mantiene compatibilidad hacia atrás con código existente
  - Reducido de 331 líneas a ~45 líneas

### Agregado (Fase 4 - Extensibilidad)
- **Módulo `commands/registry.psm1`** - Registro dinámico de comandos
  - `Get-AvailableCommands` - Lista comandos disponibles
  - `Get-CommandAlias` - Obtiene alias de comando
  - `Invoke-Command` - Ejecuta comando por alias
  - `Show-CommandsTable` - Muestra tabla de comandos

- **Documentación `docs/ARQUITECTURA.md`** - Guía técnica completa
  - Estructura de carpetas
  - Descripción de módulos
  - Flujo de datos
  - Principios SOLID aplicados
  - Guía de extensión

### Agregado (Fases 1-2)
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
