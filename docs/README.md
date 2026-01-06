# Documentación - Coolify Manager

## Índice de Documentos

| Documento                                              | Descripción                      | Estado       |
| ------------------------------------------------------ | -------------------------------- | ------------ |
| [PLAN-MAESTRO.md](./PLAN-MAESTRO.md)                   | Plan de desarrollo integral v2.0 | ✅ Activo     |
| [ARQUITECTURA.md](./ARQUITECTURA.md)                   | Documentación técnica            | ✅ Completo   |
| [CHANGELOG.md](./CHANGELOG.md)                         | Historial de cambios             | ✅ Activo     |
| [PLAN-TESTING-REFACTOR.md](./PLAN-TESTING-REFACTOR.md) | Plan anterior (superseded)       | ⚠️ Referencia |

## Resumen Ejecutivo

### Estado Actual (2026-01-06)

- **Versión:** 2.0.0 (en desarrollo)
- **Tests Manuales:** 92.9% pasando (26/28)
- **Tests Unitarios:** 84.6% pasando (33/39)
- **Problemas críticos:** 0 (todos corregidos)

### Roadmap

| Fase                 | Objetivo           | Duración | Estado |
| -------------------- | ------------------ | -------- | ------ |
| 1. Estabilización    | Sistema testeado   | Semana 1 | ✅      |
| 2. Mejora de Calidad | Código mantenible  | Semana 2 | ✅      |
| 3. Refactorización   | Arquitectura SOLID | Semana 3 | ✅      |
| 4. Extensibilidad    | Fácil de extender  | Semana 4 | ✅      |

### Próximo Paso

**Release v2.0** - Todas las fases completadas

```powershell
cd .agent\coolify-manager
.\manager.ps1 status
```

## Estructura del Proyecto

```
coolify-manager/
├── manager.ps1              # Punto de entrada
├── config/                  # Configuración
├── modules/
│   ├── Core/                # Módulos fundamentales
│   │   ├── ConfigManager.psm1
│   │   ├── Logger.psm1
│   │   └── Validators.psm1
│   ├── WordPress/           # Módulos SOLID (nuevos)
│   │   ├── ThemeManager.psm1
│   │   ├── DatabaseManager.psm1
│   │   └── SiteManager.psm1
│   ├── CoolifyApi.psm1
│   ├── SshOperations.psm1
│   └── WordPressManager.psm1  # Facade (compatibilidad)
├── commands/
│   ├── registry.psm1        # Registro dinámico
│   └── *.ps1                # Comandos
├── templates/               # Plantillas Docker
├── tests/
│   ├── Unit/                # Tests unitarios
│   └── Integration/         # Tests integración
└── docs/                    # Documentación (aquí)
```

## Contacto

Para dudas o contribuciones, revisar el código y documentación en este directorio.
