# Documentación - Coolify Manager

## Índice de Documentos

| Documento                                              | Descripción                      | Estado       |
| ------------------------------------------------------ | -------------------------------- | ------------ |
| [PLAN-MAESTRO.md](./PLAN-MAESTRO.md)                   | Plan de desarrollo integral v2.0 | ✅ Activo     |
| [PLAN-TESTING-REFACTOR.md](./PLAN-TESTING-REFACTOR.md) | Plan anterior (superseded)       | ⚠️ Referencia |
| ARQUITECTURA.md                                        | Documentación técnica            | 🔲 Pendiente  |
| CHANGELOG.md                                           | Historial de cambios             | 🔲 Pendiente  |

## Resumen Ejecutivo

### Estado Actual (2026-01-06)

- **Versión:** 1.0.0
- **Tests:** 92.9% pasando (26/28)
- **Problemas críticos:** 2 (password hardcodeado, SSH bloqueado)

### Roadmap

| Fase                 | Objetivo           | Duración | Estado |
| -------------------- | ------------------ | -------- | ------ |
| 1. Estabilización    | Sistema testeado   | Semana 1 | 🔲      |
| 2. Mejora de Calidad | Código mantenible  | Semana 2 | 🔲      |
| 3. Refactorización   | Arquitectura SOLID | Semana 3 | 🔲      |
| 4. Extensibilidad    | Fácil de extender  | Semana 4 | 🔲      |

### Próximo Paso

**Ejecutar tests manuales completos** según checklist en PLAN-MAESTRO.md

```powershell
cd .agent\coolify-manager
.\tests\Test-Manual.ps1
```

## Estructura del Proyecto

```
coolify-manager/
├── manager.ps1          # Punto de entrada
├── config/              # Configuración
├── modules/             # Módulos PowerShell
├── commands/            # Comandos disponibles
├── templates/           # Plantillas Docker
├── tests/               # Tests
└── docs/                # Documentación (aquí)
```

## Contacto

Para dudas o contribuciones, revisar el código y documentación en este directorio.
