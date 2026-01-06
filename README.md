<p align="center">
  <h1 align="center">Coolify Manager</h1>
  <p align="center">
    <strong>Herramienta de automatización para gestionar sitios WordPress en Coolify</strong>
  </p>
  <p align="center">
    <a href="#instalacion">Instalación</a> •
    <a href="#uso-rapido">Uso rápido</a> •
    <a href="#comandos">Comandos</a> •
    <a href="#configuracion">Configuración</a> •
    <a href="#documentacion">Documentación</a>
  </p>
</p>

---

## Descripción

**Coolify Manager** es una CLI en PowerShell que automatiza la gestión de sitios WordPress desplegados en [Coolify](https://coolify.io/). Diseñada tanto para uso manual como para integración con asistentes de IA.

### Características

- Crear stacks WordPress completos (WordPress + MariaDB)
- Gestionar múltiples sitios desde una sola herramienta
- Desplegar y actualizar temas automáticamente
- Importar bases de datos con corrección de URLs
- Ejecutar comandos en contenedores Docker
- Ver logs en tiempo real
- Sistema de validación y logging integrado

---

## Requisitos

- **Windows 10/11** con PowerShell 5.1+
- **SSH configurado** con clave pública en el VPS
- **Coolify** instalado y funcionando en el servidor
- **Token API** de Coolify

---

## Instalación

### 1. Clonar el repositorio

```powershell
git clone https://github.com/1ndoryu/coolify-manager.git
cd coolify-manager
```

### 2. Configurar credenciales

Copia el template de configuración:

```powershell
Copy-Item .\config\settings.template.json .\config\settings.json
```

Edita `config/settings.json` con tus datos:

```json
{
    "vps": {
        "ip": "TU_IP_VPS",
        "user": "root"
    },
    "coolify": {
        "baseUrl": "http://TU_IP_VPS:8000",
        "apiToken": "TU_TOKEN_API",
        "serverUuid": "TU_SERVER_UUID",
        "projectUuid": "TU_PROJECT_UUID"
    }
}
```

### 3. Verificar instalación

```powershell
.\manager.ps1 status
```

---

## Uso Rápido

```powershell
# Listar todos los sitios
.\manager.ps1 list

# Crear nuevo sitio WordPress
.\manager.ps1 new -SiteName "mi-blog" -Domain "https://mi-blog.com"

# Ver logs de un sitio
.\manager.ps1 logs -SiteName "mi-blog"

# Reiniciar un sitio
.\manager.ps1 restart -SiteName "mi-blog"
```

---

## Comandos

### `list` - Listar sitios

```powershell
.\manager.ps1 list
.\manager.ps1 list -Detailed    # Con info de contenedores
```

### `new` - Crear sitio

```powershell
.\manager.ps1 new -SiteName "tienda" -Domain "https://tienda.com"
.\manager.ps1 new -SiteName "test" -Domain "https://test.com" -SkipTheme
```

### `restart` - Reiniciar

```powershell
.\manager.ps1 restart -SiteName "mi-blog"
.\manager.ps1 restart -All                    # Todos los sitios
.\manager.ps1 restart -SiteName "blog" -OnlyWordPress
```

### `deploy` - Desplegar tema

```powershell
.\manager.ps1 deploy -SiteName "blog" -GloryBranch "main"
.\manager.ps1 deploy -SiteName "blog" -Update    # Solo actualizar
```

### `import` - Importar base de datos

```powershell
.\manager.ps1 import -SiteName "blog" -SqlFile ".\backup.sql"
.\manager.ps1 import -SiteName "blog" -SqlFile ".\backup.sql" -FixUrls
```

### `exec` - Ejecutar comandos

```powershell
# Comando bash
.\manager.ps1 exec -SiteName "blog" -Command "ls -la /var/www/html"

# Código PHP
.\manager.ps1 exec -SiteName "blog" -PhpCode "echo get_option('siteurl');"
```

### `logs` - Ver logs

```powershell
.\manager.ps1 logs -SiteName "blog"
.\manager.ps1 logs -SiteName "blog" -Lines 200
.\manager.ps1 logs -SiteName "blog" -Target mariadb
.\manager.ps1 logs -SiteName "blog" -Follow    # Tiempo real
```

### `status` - Estado del sistema

```powershell
.\manager.ps1 status
```

---

## Configuración

### Variables de Entorno (Recomendado)

Para mayor seguridad, usa variables de entorno:

```powershell
$env:COOLIFY_API_TOKEN = "tu-token-aqui"
$env:COOLIFY_VPS_IP = "66.94.100.241"
$env:COOLIFY_VPS_USER = "root"
$env:COOLIFY_DB_PASSWORD = "password-db"
```

### Archivo de Configuración

El archivo `config/settings.json` soporta interpolación de variables:

```json
{
    "coolify": {
        "apiToken": "${COOLIFY_API_TOKEN}"
    }
}
```

---

## Estructura del Proyecto

```
coolify-manager/
├── manager.ps1              # Punto de entrada
├── config/
│   ├── settings.json        # Config local (no en git)
│   └── settings.template.json
├── modules/
│   ├── Core/                # Módulos fundamentales
│   │   ├── Logger.psm1      # Sistema de logs
│   │   ├── ConfigManager.psm1
│   │   └── Validators.psm1
│   ├── WordPress/           # Módulos SOLID (v2.0)
│   │   ├── ThemeManager.psm1    # Gestión del tema Glory
│   │   ├── DatabaseManager.psm1 # Operaciones de BD
│   │   └── SiteManager.psm1     # Configuración de sitio
│   ├── CoolifyApi.psm1      # API REST Coolify
│   ├── SshOperations.psm1   # SSH/Docker
│   └── WordPressManager.psm1 # Facade (compatibilidad)
├── commands/
│   ├── registry.psm1        # Registro dinámico de comandos
│   ├── new-site.ps1
│   ├── list-sites.ps1
│   ├── restart-site.ps1
│   └── ...
├── templates/
│   └── wordpress-stack.yaml
├── tests/
│   ├── Unit/                # Tests unitarios Pester
│   ├── Integration/         # Tests de integración
│   ├── Test-Manual.ps1
│   └── Test-Ssh.ps1
└── docs/
    ├── PLAN-MAESTRO.md
    ├── ARQUITECTURA.md
    └── CHANGELOG.md
```

---

## Documentación

- [Plan Maestro](docs/PLAN-MAESTRO.md) - Roadmap y arquitectura
- [Changelog](docs/CHANGELOG.md) - Historial de cambios
- [Guía de Testing](docs/PLAN-TESTING-REFACTOR.md)

---

## Uso por IA

Esta herramienta está diseñada para ser usada por asistentes de IA. Los módulos exportan funciones documentadas:

```powershell
Import-Module ".\modules\CoolifyApi.psm1"

$services = Get-CoolifyServices
Restart-CoolifyService -Uuid "abc123..."
```

### Funciones Disponibles

| Módulo                         | Funciones                                             |
| ------------------------------ | ----------------------------------------------------- |
| CoolifyApi.psm1                | Get-CoolifyServices, New-CoolifyWordPressStack, etc.  |
| SshOperations.psm1             | Invoke-SshCommand, Get-DockerContainers, etc.         |
| WordPress/ThemeManager.psm1    | Install-GloryTheme, Update-GloryTheme                 |
| WordPress/DatabaseManager.psm1 | Import-WordPressDatabase, Export-WordPressDatabase    |
| WordPress/SiteManager.psm1     | Get-SiteConfig, Set-WordPressUrls, New-WordPressAdmin |
| Core/Validators.psm1           | Test-SiteExists, Test-DomainFormat, Assert-SiteReady  |
| Core/Logger.psm1               | Write-Log, Get-LogEntries, Clear-OldLogs              |
| Core/ConfigManager.psm1        | Get-Config, Get-DbPassword, Get-AllSites              |

---

## Tests

```powershell
# Tests manuales
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Manual.ps1"

# Tests unitarios (requiere Pester)
Invoke-Pester -Path ".\tests\Unit\"

# Diagnóstico SSH
powershell -ExecutionPolicy Bypass -File ".\tests\Test-Ssh.ps1"
```

---

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para guía de contribución.

---

## Licencia

[MIT License](LICENSE)

---

## Autor

Desarrollado por [1ndoryu](https://github.com/1ndoryu)
