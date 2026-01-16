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
    },
    "glory": {
        "templateRepo": "https://github.com/tu-usuario/tu-template.git",
        "libraryRepo": "https://github.com/tu-usuario/glory.git"
    },
    "sitios": [
        {
            "nombre": "mi-sitio",
            "dominio": "https://mi-sitio.com",
            "stackUuid": "UUID_DEL_STACK_EN_COOLIFY",
            "gloryBranch": "main",
            "libraryBranch": "main",
            "themeName": "glory"
        }
    ]
}
```

**Campos importantes de sitios:**
- `stackUuid`: UUID del stack en Coolify (visible en la URL del stack)
- `themeName`: Nombre exacto de la carpeta del tema en `/wp-content/themes/` (sensible a mayúsculas)

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
.\\manager.ps1 logs -SiteName "blog"
.\\manager.ps1 logs -SiteName "blog" -Lines 200
.\\manager.ps1 logs -SiteName "blog" -Target mariadb
.\\manager.ps1 logs -SiteName "blog" -Follow    # Tiempo real

# Ver debug.log de WordPress (requiere debug habilitado)
.\\manager.ps1 logs -SiteName "blog" -WpDebug
.\\manager.ps1 logs -SiteName "blog" -WpDebug -Filter "AmazonAJAX"
```

### `debug` - Gestionar modo debug de WordPress

```powershell
# Ver estado actual
.\\manager.ps1 debug -SiteName "blog"

# Habilitar modo debug (WP_DEBUG + WP_DEBUG_LOG)
.\\manager.ps1 debug -SiteName "blog" -Enable

# Deshabilitar modo debug
.\\manager.ps1 debug -SiteName "blog" -Disable
```

### `cache` - Gestionar cache headers HTTP

Mejora el rendimiento configurando headers de caché para archivos estáticos (CSS, JS, imágenes, fuentes).

```powershell
# Ver estado actual
.\\manager.ps1 cache -SiteName "blog"

# Habilitar cache headers
.\\manager.ps1 cache -SiteName "blog" -Enable

# Deshabilitar cache headers  
.\\manager.ps1 cache -SiteName "blog" -Disable

# Aplicar a todos los sitios
.\\manager.ps1 cache -All -Status
.\\manager.ps1 cache -All -Enable
```

**Qué hace:**
- Agrega reglas al `.htaccess` para cachear archivos estáticos
- Imágenes y fuentes: 1 año (inmutables)
- CSS y JS: 1 mes (WordPress usa `?ver=` para cache busting)
- HTML: sin caché (contenido dinámico)
- Habilita automáticamente los módulos `mod_expires` y `mod_headers` de Apache

### `status` - Estado del sistema

```powershell
.\\manager.ps1 status
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

| Módulo                         | Funciones                                                  |
| ------------------------------ | ---------------------------------------------------------- |
| CoolifyApi.psm1                | Get-CoolifyServices, New-CoolifyWordPressStack, etc.       |
| SshOperations.psm1             | Invoke-SshCommand, Get-DockerContainers, etc.              |
| WordPress/ThemeManager.psm1    | Install-GloryTheme, Update-GloryTheme                      |
| WordPress/DatabaseManager.psm1 | Import-WordPressDatabase, Export-WordPressDatabase         |
| WordPress/SiteManager.psm1     | Get-SiteConfig, Set-WordPressUrls, New-WordPressAdmin      |
| WordPress/CacheManager.psm1    | Get-CacheStatus, Enable-CacheHeaders, Disable-CacheHeaders |
| Core/Validators.psm1           | Test-SiteExists, Test-DomainFormat, Assert-SiteReady       |
| Core/Logger.psm1               | Write-Log, Get-LogEntries, Clear-OldLogs                   |
| Core/ConfigManager.psm1        | Get-Config, Get-DbPassword, Get-AllSites                   |

---

## Notas Técnicas

### Compatibilidad Windows → Linux

Esta herramienta se ejecuta desde Windows pero envía comandos a contenedores Linux. Para evitar problemas:

1. **Caracteres `\r` (CR)**: Los here-strings de PowerShell incluyen `\r\n`. El módulo `SshOperations.psm1` limpia automáticamente los `\r` antes de enviar comandos a Linux.

2. **Rutas absolutas**: Los scripts de deploy usan rutas absolutas completas (ej: `/var/www/html/wp-content/themes/glory`) en lugar de rutas relativas para evitar errores de `cd`.

3. **Git safe.directory**: Los scripts configuran automáticamente `git config --global --add safe.directory` para evitar errores de "dubious ownership" cuando el contenedor ejecuta como root.

### Warnings Esperados

Al ejecutar `deploy -Update`, pueden aparecer estos mensajes que **NO son errores**:

| Mensaje                                  | Explicación                        |
| ---------------------------------------- | ---------------------------------- |
| `packages are looking for funding`       | Normal de npm/composer             |
| `Some chunks are larger than 500 kB`     | Sugerencia de optimización de Vite |
| `does not comply with psr-4 autoloading` | Warning de naming en código PHP    |

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
