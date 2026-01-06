# Guía de Contribución

Gracias por tu interés en contribuir a **Coolify Manager**.

## Cómo Contribuir

### Reportar Bugs

1. Verifica que el bug no haya sido reportado previamente en [Issues](../../issues)
2. Si no existe, crea un nuevo issue con:
   - Descripción clara del problema
   - Pasos para reproducirlo
   - Comportamiento esperado vs actual
   - Versión de PowerShell (`$PSVersionTable.PSVersion`)
   - Sistema operativo

### Proponer Mejoras

1. Abre un issue describiendo la mejora
2. Espera feedback antes de implementar cambios grandes
3. Para cambios pequeños, puedes enviar un PR directamente

### Pull Requests

1. Haz fork del repositorio
2. Crea una rama descriptiva: `feature/nueva-funcionalidad` o `fix/correccion-bug`
3. Sigue las convenciones de código
4. Incluye tests para nuevas funcionalidades
5. Actualiza la documentación si es necesario
6. Envía el PR con descripción clara

## Convenciones de Código

### Nomenclatura

- **Variables y funciones**: `camelCase`
- **Funciones PowerShell**: `Verb-Noun` (Get-Config, Set-Value)
- **Archivos**: `NombreDescriptivo.ps1` o `nombre-descriptivo.ps1`

### Estructura de Archivos

- Máximo **300 líneas** por archivo
- Un archivo = una responsabilidad
- Documentar funciones con comentarios

### Commits

- Mensajes en español
- Formato: `tipo: descripción breve`
- Tipos: `feat`, `fix`, `docs`, `refactor`, `test`

Ejemplo:
```
feat: agregar validación de dominio
fix: corregir timeout en conexión SSH
docs: actualizar guía de instalación
```

## Ejecutar Tests

```powershell
# Tests manuales
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Manual.ps1"

# Tests unitarios (requiere Pester)
Invoke-Pester -Path ".\tests\Unit\"
```

## Estructura del Proyecto

```
coolify-manager/
├── commands/       # Comandos ejecutables
├── config/         # Configuración
├── docs/           # Documentación
├── logs/           # Logs (ignorado en git)
├── modules/        # Módulos PowerShell
│   └── Core/       # Módulos fundamentales
├── templates/      # Plantillas
└── tests/          # Tests
    └── Unit/       # Tests unitarios
```

## Preguntas

Si tienes dudas, abre un issue con la etiqueta `question`.

---

¡Gracias por contribuir!
