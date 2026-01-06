# Tests - Coolify Manager

Directorio de tests para validar el funcionamiento de Coolify Manager.

## Estructura

```
tests/
├── Test-Manual.ps1     # Tests principales (API, HTTP, Config)
├── Test-Ssh.ps1        # Diagnóstico de conexión SSH
├── results_*.json      # Resultados de ejecuciones
└── README.md           # Este archivo
```

## Ejecutar Tests

### Tests Principales (no requiere SSH)

```powershell
cd .agent\coolify-manager
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Manual.ps1"
```

Estos tests verifican:
- Conexión a la API de Coolify
- Estado de los servicios
- Configuración local
- Acceso HTTP a los sitios
- Existencia de módulos y comandos

### Test de SSH (diagnóstico)

```powershell
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Ssh.ps1"
```

Ejecutar si hay problemas con comandos que usan SSH.

## Resultados

Los resultados se guardan en formato JSON:
```
results_YYYY-MM-DD_HHmmss.json
```

Ejemplo de resultado:
```json
{
    "Test": "API Coolify conecta",
    "Passed": true,
    "Message": "Version: 4.0.0-beta.460",
    "Timestamp": "2026-01-05T16:38:35"
}
```

## Última Ejecución

| Fecha      | Tests | Pasados | Fallidos | Tasa  |
| ---------- | ----- | ------- | -------- | ----- |
| 2026-01-05 | 28    | 26      | 2        | 92.9% |

### Issues Detectados

1. **Servicio "Wordpress" en `exited`** - Revisar en Coolify
2. **Sitio `guillermo` sin UUID** - Agregar stackUuid a settings.json

## Agregar Nuevos Tests

Para agregar un nuevo test, usar la función `Write-TestResult`:

```powershell
Write-TestResult -TestName "Mi nuevo test" -Passed $true -Message "Funciona"
```

Los tests se agregan automáticamente a `$script:TestResults` para el resumen.
