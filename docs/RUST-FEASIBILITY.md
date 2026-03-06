# Coolify Manager Rust — Estudio de Factibilidad

> Evaluacion completa para reescribir coolify-manager en Rust con arquitectura mejorada,
> error handling exhaustivo, eficiencia nativa y servidor MCP para integracion con VS Code.
> Fecha: 2026-03-05

---

## 1. Estado actual del proyecto

Coolify Manager es una herramienta CLI en **PowerShell 5.1** (~4,700 LOC) que automatiza la gestion de sitios WordPress desplegados en Coolify. Opera sobre SSH y la API REST de Coolify.

### Resumen del stack actual

| Aspecto                   | Actual (PowerShell)          |
| ------------------------- | ---------------------------- |
| **Lenguaje**              | PowerShell 5.1               |
| **LOC totales**           | ~4,700                       |
| **Modulos**               | 11 (.psm1)                   |
| **Comandos**              | 15 (.ps1)                    |
| **Templates**             | 3 (Docker Compose YAML)      |
| **Tests**                 | 8 archivos (Pester + manual) |
| **Dependencias externas** | 0 (solo cmdlets nativos)     |
| **Portabilidad**          | Windows only (PS 5.1)        |
| **Type safety**           | Ninguna (dynamically typed)  |
| **Concurrencia**          | Ninguna                      |
| **MCP**                   | No existe                    |

### Debilidades detectadas en el codigo actual

1. **Sin tipos estaticos**: errores de parametros solo se detectan en runtime (BUG-01, BUG-03 del CHANGELOG)
2. **Escape de strings fragil**: Windows `\r\n` → Linux causa bugs silenciosos (BUG-02)
3. **Sin concurrencia**: operaciones multi-sitio son secuenciales
4. **Error handling inconsistente**: algunos modulos usan try-catch, otros usan `$ErrorActionPreference = 'SilentlyContinue'`
5. **SSH como texto plano**: parsear salida de `ssh.exe` es fragil y propenso a errores
6. **Sin validacion de schema**: `settings.json` se valida parcialmente
7. **Sin rollback**: si falla un paso del flujo `new-site`, quedan recursos huerfanos
8. **Tests limitados**: 92.9% pass rate pero tests manuales, no automatizados en CI
9. **Solo Windows**: PowerShell 5.1 no corre nativamente en Linux/macOS

---

## 2. Que ganaria una reescritura en Rust

### 2.1 Mejoras directas

| Dimension             | PowerShell actual             | Rust propuesto                        | Ganancia                               |
| --------------------- | ----------------------------- | ------------------------------------- | -------------------------------------- |
| **Type safety**       | Ninguna                       | Compilacion + ownership               | Elimina categorias enteras de bugs     |
| **Performance**       | Interprete lento, startup ~2s | Binario nativo, startup <50ms         | ~40x mas rapido en operaciones CPU     |
| **Concurrencia**      | Imposible en PS 5.1           | async/await nativo (tokio)            | Deploy a N sitios en paralelo          |
| **Error handling**    | Try-catch inconsistente       | `Result<T, E>` obligatorio            | Zero errores silenciosos               |
| **Portabilidad**      | Windows only                  | Linux, macOS, Windows                 | Un binario para todo                   |
| **Binario unico**     | Requiere PS instalado         | Binario estatico autocontenido        | Cero dependencias de runtime           |
| **SSH**               | Texto plano via `ssh.exe`     | `russh` (SSH nativo en Rust)          | Conexiones persistentes, multiplexadas |
| **Seguridad**         | Strings en memoria            | Zeroize, sin buffer overflows         | Secrets borrados de RAM al usarlos     |
| **MCP**               | No existe                     | Servidor MCP integrado                | Control total desde VS Code            |
| **Config validation** | Parcial, runtime              | Serde + validacion en deserializacion | Errores de config en el instante       |

### 2.2 Mejoras arquitectonicas

**Problema actual:** Los modulos de PowerShell se importan con `Import-Module -Force`, no hay inyeccion de dependencias real, y la composicion es ad-hoc.

**En Rust:**

- Traits como contratos entre capas (verdadera DIP)
- Modulos con visibilidad controlada por el compilador
- Error types por dominio (no strings genericos)
- Builder pattern para configuraciones complejas
- Async nativo para I/O bound operations (SSH, HTTP, Docker)

---

## 3. Mapping modulo por modulo — PowerShell a Rust

### 3.1 Equivalencias directas

| Modulo PS (.psm1)           | Crate/Modulo Rust     | Crate externo                    | Complejidad |
| --------------------------- | --------------------- | -------------------------------- | ----------- |
| `ConfigManager`             | `config::manager`     | `serde`, `serde_json`, `figment` | BAJA        |
| `Logger`                    | `logging`             | `tracing`, `tracing-subscriber`  | BAJA        |
| `Validators`                | `validation`          | `validator` (derive macros)      | BAJA        |
| `CoolifyApi`                | `api::coolify`        | `reqwest`, `serde`               | BAJA        |
| `SshOperations`             | `ssh::operations`     | `russh`, `russh-sftp`            | MEDIA       |
| `ThemeManager`              | `wordpress::theme`    | _usa ssh + api_                  | MEDIA       |
| `DatabaseManager`           | `wordpress::database` | _usa ssh_                        | BAJA        |
| `SiteManager`               | `wordpress::site`     | _usa ssh + api_                  | MEDIA       |
| `CacheManager`              | `wordpress::cache`    | _usa ssh_                        | BAJA        |
| `WordPressManager` (facade) | **Se elimina**        | —                                | —           |
| `registry.psm1`             | `commands::registry`  | `clap` (subcommands)             | BAJA        |

### 3.2 Modulos nuevos (no existen en PS)

| Modulo              | Proposito                               | Crate                          |
| ------------------- | --------------------------------------- | ------------------------------ |
| `mcp::server`       | Servidor MCP para VS Code               | `tokio`, `serde_json`, `tower` |
| `mcp::tools`        | Herramientas MCP (cada comando = tool)  | —                              |
| `mcp::resources`    | Recursos MCP (config, logs, status)     | —                              |
| `rollback::manager` | Rollback transaccional de operaciones   | —                              |
| `template::engine`  | Renderizado de Docker Compose templates | `tera` o `handlebars`          |
| `health::checker`   | Health checks de servicios y conexiones | `reqwest`, `russh`             |

---

## 4. Arquitectura propuesta

### 4.1 Capas

```
                          ┌──────────────────────────────────┐
                          │       INTERFAZ DE USUARIO        │
                          │                                  │
                          │  ┌────────────┐  ┌───────────┐  │
                          │  │  CLI(clap) │  │MCP Server │  │
                          │  └─────┬──────┘  └─────┬─────┘  │
                          │        │               │         │
                          └────────┼───────────────┼─────────┘
                                   │               │
                          ┌────────▼───────────────▼─────────┐
                          │      CAPA DE APLICACION          │
                          │                                  │
                          │  ┌───────────────────────────┐   │
                          │  │  CommandDispatcher         │   │
                          │  │  (resuelve cmd → handler)  │   │
                          │  └─────────┬─────────────────┘   │
                          │            │                     │
                          │  ┌─────────▼─────────────────┐   │
                          │  │  Handlers (1 por comando)  │   │
                          │  │  NewSite, Deploy, Import.. │   │
                          │  └─────────┬─────────────────┘   │
                          │            │                     │
                          └────────────┼─────────────────────┘
                                       │
                          ┌────────────▼─────────────────────┐
                          │       CAPA DE DOMINIO            │
                          │                                  │
                          │  ┌─────────────┐ ┌────────────┐  │
                          │  │ SiteManager │ │ThemeManager│  │
                          │  └──────┬──────┘ └─────┬──────┘  │
                          │         │              │         │
                          │  ┌──────┴──────┐ ┌─────┴──────┐  │
                          │  │ DbManager   │ │CacheManager│  │
                          │  └──────┬──────┘ └─────┬──────┘  │
                          │         │              │         │
                          │  ┌──────┴──────────────┴──────┐  │
                          │  │   RollbackManager           │  │
                          │  │   (transacciones reversibles)│  │
                          │  └─────────────┬──────────────┘  │
                          └────────────────┼─────────────────┘
                                           │
                          ┌────────────────▼─────────────────┐
                          │     CAPA DE INFRAESTRUCTURA      │
                          │                                  │
                          │  ┌────────────┐  ┌────────────┐  │
                          │  │ CoolifyApi │  │  SshClient │  │
                          │  │ (reqwest)  │  │  (russh)   │  │
                          │  └────────────┘  └────────────┘  │
                          │                                  │
                          │  ┌────────────┐  ┌────────────┐  │
                          │  │  Config    │  │  Logger    │  │
                          │  │ (figment)  │  │ (tracing)  │  │
                          │  └────────────┘  └────────────┘  │
                          │                                  │
                          │  ┌────────────┐  ┌────────────┐  │
                          │  │  Template  │  │  Secrets   │  │
                          │  │  (tera)    │  │ (zeroize)  │  │
                          │  └────────────┘  └────────────┘  │
                          └──────────────────────────────────┘
```

### 4.2 Estructura de carpetas propuesta

```
coolify-manager-rs/
├── Cargo.toml
├── Cargo.lock
├── README.md
├── config/
│   ├── settings.json
│   └── settings.template.json
├── templates/
│   ├── wordpress-stack.yaml.tera
│   ├── kamples-stack.yaml.tera
│   └── minecraft-stack.yaml.tera
├── src/
│   ├── main.rs                     # Entry point: CLI o MCP segun args
│   ├── lib.rs                      # Re-exports publicos
│   │
│   ├── cli/
│   │   ├── mod.rs                  # CLI con clap (subcommands)
│   │   └── output.rs              # Formateo de salida (colores, tablas)
│   │
│   ├── mcp/
│   │   ├── mod.rs                  # Servidor MCP (stdio transport)
│   │   ├── server.rs              # Lifecycle: initialize, shutdown
│   │   ├── tools.rs               # Registro de tools (1 por comando)
│   │   ├── resources.rs           # Recursos: config, logs, site status
│   │   └── prompts.rs             # Prompts predefinidos (opcional)
│   │
│   ├── commands/
│   │   ├── mod.rs                  # Dispatcher + trait CommandHandler
│   │   ├── new_site.rs
│   │   ├── deploy_theme.rs
│   │   ├── import_database.rs
│   │   ├── export_database.rs
│   │   ├── list_sites.rs
│   │   ├── restart_site.rs
│   │   ├── exec_command.rs
│   │   ├── view_logs.rs
│   │   ├── debug_site.rs
│   │   ├── cache_site.rs
│   │   ├── git_status.rs
│   │   ├── set_domain.rs
│   │   ├── redeploy.rs
│   │   ├── setup_smtp.rs
│   │   └── minecraft.rs
│   │
│   ├── domain/
│   │   ├── mod.rs
│   │   ├── site.rs                 # Struct Site, SiteStatus, etc.
│   │   ├── theme.rs                # ThemeConfig, ThemeBranch
│   │   ├── stack.rs                # Stack, StackTemplate
│   │   └── server.rs              # ServerConfig, MinecraftServer
│   │
│   ├── services/
│   │   ├── mod.rs
│   │   ├── site_manager.rs
│   │   ├── theme_manager.rs
│   │   ├── database_manager.rs
│   │   ├── cache_manager.rs
│   │   └── rollback.rs            # RollbackManager con transacciones
│   │
│   ├── infra/
│   │   ├── mod.rs
│   │   ├── coolify_api.rs         # Cliente Coolify REST
│   │   ├── ssh_client.rs          # SSH nativo con russh
│   │   ├── docker.rs              # Operaciones Docker sobre SSH
│   │   ├── template_engine.rs     # Tera/Handlebars para YAML
│   │   └── secrets.rs             # Manejo seguro de credenciales
│   │
│   ├── config/
│   │   ├── mod.rs
│   │   ├── settings.rs            # Struct Settings con Deserialize
│   │   ├── validation.rs          # Reglas de validacion de config
│   │   └── env.rs                 # Expansion de variables de entorno
│   │
│   ├── logging/
│   │   ├── mod.rs
│   │   └── file_layer.rs          # Log a archivo con rotacion
│   │
│   └── error/
│       ├── mod.rs                  # CoolifyError enum (thiserror)
│       ├── api.rs                  # Errores de API
│       ├── ssh.rs                  # Errores de SSH
│       └── config.rs              # Errores de config
│
└── tests/
    ├── common/
    │   └── mod.rs                  # Helpers de test compartidos
    ├── unit/
    │   ├── config_test.rs
    │   ├── validation_test.rs
    │   └── template_test.rs
    └── integration/
        ├── coolify_api_test.rs
        ├── ssh_test.rs
        └── mcp_test.rs
```

### 4.3 Trait-based architecture (DIP real)

```rust
/* Contratos entre capas — los services dependen de traits, no de implementaciones */

#[async_trait]
pub trait InfraApi: Send + Sync {
    async fn get_services(&self) -> Result<Vec<Service>>;
    async fn create_stack(&self, template: &StackTemplate) -> Result<StackResult>;
    async fn start_service(&self, uuid: &str) -> Result<()>;
    async fn stop_service(&self, uuid: &str) -> Result<()>;
    async fn restart_service(&self, uuid: &str) -> Result<()>;
}

#[async_trait]
pub trait SshExecutor: Send + Sync {
    async fn execute(&self, command: &str) -> Result<CommandOutput>;
    async fn upload_file(&self, local: &Path, remote: &str) -> Result<()>;
    async fn download_file(&self, remote: &str, local: &Path) -> Result<()>;
    async fn docker_exec(&self, container: &str, cmd: &str) -> Result<CommandOutput>;
    async fn find_container(&self, filter: &ContainerFilter) -> Result<String>;
}

#[async_trait]
pub trait ConfigProvider: Send + Sync {
    fn get_settings(&self) -> &Settings;
    fn get_site(&self, name: &str) -> Result<&SiteConfig>;
    fn get_vps(&self) -> &VpsConfig;
    fn get_coolify(&self) -> &CoolifyConfig;
    fn get_db_password(&self, site_name: &str) -> Result<SecretString>;
}
```

Con esto, los tests unitarios pueden usar mocks:

```rust
#[cfg(test)]
struct MockSsh;

#[async_trait]
impl SshExecutor for MockSsh {
    async fn execute(&self, command: &str) -> Result<CommandOutput> {
        Ok(CommandOutput { stdout: "ok".into(), stderr: "".into(), exit_code: 0 })
    }
    /* ... */
}
```

---

## 5. Sistema de errores — Zero fallos silenciosos

### 5.1 Tipo de error por dominio

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CoolifyError {
    /* Errores de configuracion */
    #[error("Configuracion invalida: {0}")]
    Config(#[from] ConfigError),

    /* Errores de API Coolify */
    #[error("API Coolify fallo: {0}")]
    Api(#[from] ApiError),

    /* Errores de SSH */
    #[error("Operacion SSH fallo: {0}")]
    Ssh(#[from] SshError),

    /* Errores de Docker */
    #[error("Docker exec fallo (exit {exit_code}): {stderr}")]
    Docker { exit_code: i32, stderr: String },

    /* Errores de validacion */
    #[error("Validacion: {0}")]
    Validation(String),

    /* Sitio no encontrado */
    #[error("Sitio '{0}' no encontrado en configuracion")]
    SiteNotFound(String),

    /* Operacion cancelada por rollback */
    #[error("Operacion revertida: {0}")]
    RolledBack(String),
}

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("HTTP {status}: {body}")]
    HttpError { status: u16, body: String },

    #[error("Timeout despues de {seconds}s")]
    Timeout { seconds: u64 },

    #[error("Red: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Respuesta invalida: {0}")]
    InvalidResponse(#[from] serde_json::Error),
}

#[derive(Error, Debug)]
pub enum SshError {
    #[error("Conexion rechazada a {host}: {reason}")]
    ConnectionRefused { host: String, reason: String },

    #[error("Autenticacion fallida para {user}@{host}")]
    AuthFailed { user: String, host: String },

    #[error("Comando fallo (exit {exit_code}): {stderr}")]
    CommandFailed { exit_code: i32, stderr: String },

    #[error("Contenedor '{filter}' no encontrado")]
    ContainerNotFound { filter: String },

    #[error("Timeout en canal SSH despues de {seconds}s")]
    ChannelTimeout { seconds: u64 },
}
```

**Comparacion directa con PowerShell:**

| Escenario                 | PowerShell (actual)                                              | Rust (propuesto)                                    |
| ------------------------- | ---------------------------------------------------------------- | --------------------------------------------------- |
| SSH falla silenciosamente | `$ErrorActionPreference = 'SilentlyContinue'` — error ignorado   | `Result<T, SshError>` — **imposible ignorar**       |
| Config invalida           | Se detecta a mitad de ejecucion                                  | Se detecta al deserializar (antes de ejecutar nada) |
| Parametro mal tipado      | Runtime `ParameterBindingException`                              | **No compila**                                      |
| Container no encontrado   | Retorna string vacio, siguiente comando falla con error criptico | `SshError::ContainerNotFound` con contexto          |
| API devuelve 500          | `Invoke-RestMethod` lanza excepcion generica                     | `ApiError::HttpError { status: 500, body: "..." }`  |

---

## 6. MCP Server — Integracion con VS Code

### 6.1 Que es MCP

Model Context Protocol (MCP) es un protocolo abierto de Anthropic que permite a LLMs (como Copilot en VS Code) usar herramientas externas. Un servidor MCP expone **tools**, **resources** y **prompts** que el agente puede invocar.

### 6.2 Por que MCP para Coolify Manager

Actualmente el flujo es:

1. Abrir terminal
2. Navegar a `.agent/coolify-manager/`
3. Escribir `.\manager.ps1 deploy -SiteName blog ...`
4. Esperar, leer output, copiar errores
5. Repetir

Con MCP el flujo seria:

1. Decirle al agente en VS Code: "despliega el tema a blog con branch ecommerce"
2. El agente invoca `coolify_deploy_theme(site_name: "blog", glory_branch: "ecommerce")`
3. Recibe resultado estructurado (JSON) y lo interpreta
4. Si falla, el agente puede diagnosticar y reintentar

### 6.3 Tools MCP propuestas

Cada comando actual se convierte en un MCP tool:

```json
{
    "tools": [
        {
            "name": "coolify_new_site",
            "description": "Crea un nuevo sitio WordPress con tema Glory en Coolify. Incluye stack Docker (WordPress + MariaDB), instalacion del tema, activacion y cache headers.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string", "description": "Nombre unico del sitio (slug)"},
                    "domain": {"type": "string", "description": "Dominio completo con protocolo (https://...)"},
                    "glory_branch": {"type": "string", "default": "main"},
                    "library_branch": {"type": "string", "default": "main"},
                    "skip_react": {"type": "boolean", "default": false},
                    "skip_cache": {"type": "boolean", "default": false}
                },
                "required": ["site_name", "domain"]
            }
        },
        {
            "name": "coolify_deploy_theme",
            "description": "Despliega o actualiza el tema Glory en un sitio existente. Ejecuta git pull, composer install y npm build.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "glory_branch": {"type": "string", "default": "main"},
                    "library_branch": {"type": "string", "default": "main"},
                    "force": {"type": "boolean", "default": false, "description": "Fuerza git reset --hard antes de pull"},
                    "skip_react": {"type": "boolean", "default": false}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_list_sites",
            "description": "Lista todos los sitios configurados con su estado, dominio y UUID de stack.",
            "inputSchema": {"type": "object", "properties": {}}
        },
        {
            "name": "coolify_exec",
            "description": "Ejecuta un comando bash o PHP dentro del contenedor WordPress de un sitio.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "command": {"type": "string", "description": "Comando bash a ejecutar"},
                    "as_php": {"type": "boolean", "default": false, "description": "Ejecutar como script PHP"}
                },
                "required": ["site_name", "command"]
            }
        },
        {
            "name": "coolify_import_db",
            "description": "Importa un archivo SQL en la base de datos WordPress del sitio.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "sql_file_path": {"type": "string", "description": "Ruta local al archivo .sql"},
                    "fix_urls": {"type": "boolean", "default": false}
                },
                "required": ["site_name", "sql_file_path"]
            }
        },
        {
            "name": "coolify_export_db",
            "description": "Exporta la base de datos WordPress de un sitio a un archivo SQL local.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "output_path": {"type": "string"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_view_logs",
            "description": "Obtiene los logs del contenedor WordPress o del debug.log de WordPress.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "lines": {"type": "integer", "default": 50},
                    "wp_debug": {"type": "boolean", "default": false, "description": "Ver debug.log en vez de container logs"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_restart",
            "description": "Reinicia los servicios (contenedores) de un sitio.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_cache",
            "description": "Gestiona cache headers HTTP de un sitio WordPress.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "action": {"type": "string", "enum": ["status", "enable", "disable"]}
                },
                "required": ["site_name", "action"]
            }
        },
        {
            "name": "coolify_debug",
            "description": "Activa o desactiva WP_DEBUG en un sitio WordPress.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "enable": {"type": "boolean"}
                },
                "required": ["site_name", "enable"]
            }
        },
        {
            "name": "coolify_set_domain",
            "description": "Cambia el dominio de un sitio WordPress (URLs de WP + config de stack).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"},
                    "new_domain": {"type": "string"}
                },
                "required": ["site_name", "new_domain"]
            }
        },
        {
            "name": "coolify_git_status",
            "description": "Muestra el estado de git del tema Glory en el contenedor remoto.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_redeploy",
            "description": "Redespliega un servicio via la API de Coolify (rebuild de contenedores).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_setup_smtp",
            "description": "Configura SMTP relay (Brevo) en un sitio WordPress.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "site_name": {"type": "string"}
                },
                "required": ["site_name"]
            }
        },
        {
            "name": "coolify_minecraft",
            "description": "Gestiona servidores Minecraft Java Edition en Coolify.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "action": {"type": "string", "enum": ["new", "logs", "console", "status", "restart", "remove"]},
                    "server_name": {"type": "string"},
                    "console_command": {"type": "string", "description": "Comando para la consola MC (solo con action=console)"}
                },
                "required": ["action", "server_name"]
            }
        }
    ]
}
```

### 6.4 Resources MCP

```json
{
    "resources": [
        {
            "uri": "coolify://config/settings",
            "name": "Configuracion de Coolify Manager",
            "description": "Config actual (sin secrets)",
            "mimeType": "application/json"
        },
        {
            "uri": "coolify://sites",
            "name": "Lista de sitios",
            "description": "Todos los sitios configurados con estado",
            "mimeType": "application/json"
        },
        {
            "uri": "coolify://logs/{date}",
            "name": "Logs del manager",
            "description": "Logs de operaciones del dia especificado",
            "mimeType": "text/plain"
        },
        {
            "uri": "coolify://templates/{name}",
            "name": "Docker Compose template",
            "description": "Template YAML para creacion de stacks",
            "mimeType": "text/yaml"
        }
    ]
}
```

### 6.5 Configuracion en VS Code

```jsonc
/* .vscode/mcp.json */
{
    "servers": {
        "coolify-manager": {
            "command": "coolify-manager",
            "args": ["mcp"],
            "env": {
                "COOLIFY_API_TOKEN": "${env:COOLIFY_API_TOKEN}",
                "COOLIFY_DB_PASSWORD": "${env:COOLIFY_DB_PASSWORD}"
            }
        }
    }
}
```

El binario detecta si el primer argumento es `mcp` y arranca el servidor MCP en vez del CLI interactivo. Ambos comparten el mismo core.

### 6.6 Implementacion del transporte MCP (stdio)

```rust
/* Esquema simplificado del server loop */

pub async fn run_mcp_server(config: Arc<Settings>) -> Result<()> {
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();
    let mut reader = BufReader::new(stdin);
    let mut writer = BufWriter::new(stdout);

    loop {
        let message = read_jsonrpc_message(&mut reader).await?;

        let response = match message.method.as_str() {
            "initialize" => handle_initialize(&message),
            "tools/list" => handle_tools_list(),
            "tools/call" => handle_tool_call(&message, &config).await,
            "resources/list" => handle_resources_list(),
            "resources/read" => handle_resource_read(&message, &config).await,
            "notifications/initialized" => continue, /* no response needed */
            _ => jsonrpc_error(message.id, -32601, "Method not found"),
        };

        write_jsonrpc_message(&mut writer, &response).await?;
    }
}
```

---

## 7. Sistema de rollback transaccional

Una de las mejoras mas importantes sobre el PowerShell actual.

### 7.1 Problema actual

Cuando `new-site` falla a mitad del proceso (ej: tema instala pero URLs no se configuran), quedan recursos huerfanos. No hay limpieza automatica.

### 7.2 Solucion propuesta

```rust
pub struct Transaction {
    steps: Vec<Box<dyn TransactionStep>>,
    completed: Vec<usize>,
}

#[async_trait]
pub trait TransactionStep: Send + Sync {
    fn name(&self) -> &str;
    async fn execute(&self, ctx: &mut Context) -> Result<()>;
    async fn rollback(&self, ctx: &mut Context) -> Result<()>;
}

impl Transaction {
    pub async fn run(&mut self, ctx: &mut Context) -> Result<()> {
        for (i, step) in self.steps.iter().enumerate() {
            tracing::info!("Paso {}/{}: {}", i + 1, self.steps.len(), step.name());

            match step.execute(ctx).await {
                Ok(()) => self.completed.push(i),
                Err(e) => {
                    tracing::error!("Fallo en paso '{}': {}", step.name(), e);
                    self.rollback_completed(ctx).await;
                    return Err(CoolifyError::RolledBack(format!(
                        "Fallo en '{}', {} pasos revertidos", step.name(), self.completed.len()
                    )));
                }
            }
        }
        Ok(())
    }

    async fn rollback_completed(&self, ctx: &mut Context) {
        for &i in self.completed.iter().rev() {
            let step = &self.steps[i];
            tracing::warn!("Revirtiendo paso: {}", step.name());
            if let Err(e) = step.rollback(ctx).await {
                tracing::error!("Rollback fallo para '{}': {}", step.name(), e);
            }
        }
    }
}
```

### 7.3 Ejemplo: `new-site` como transaccion

```rust
let mut tx = Transaction::new();
tx.add(CreateCoolifyStack::new(&template));     /* rollback: delete stack */
tx.add(WaitForContainers::new(uuid, 120));      /* rollback: noop */
tx.add(SetWordPressUrls::new(uuid, &domain));   /* rollback: noop */
tx.add(InstallGloryTheme::new(uuid, &branch));  /* rollback: remove theme dir */
tx.add(EnableGloryTheme::new(uuid));            /* rollback: noop */
tx.add(EnableCacheHeaders::new(uuid));          /* rollback: disable cache */
tx.add(SaveSiteToConfig::new(&site_config));    /* rollback: remove from config */

tx.run(&mut ctx).await?;
```

---

## 8. Dependencias Rust (Cargo.toml)

```toml
[package]
name = "coolify-manager"
version = "1.0.0"
edition = "2024"
description = "Herramienta de gestion para sitios WordPress en Coolify"
license = "MIT"

[dependencies]
# Async runtime
tokio = { version = "1", features = ["full"] }
async-trait = "0.1"

# CLI
clap = { version = "4", features = ["derive"] }

# HTTP client (para Coolify API)
reqwest = { version = "0.12", features = ["json", "rustls-tls"] }

# SSH nativo
russh = "0.46"
russh-keys = "0.46"
russh-sftp = "2"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Config management
figment = { version = "0.10", features = ["json", "env"] }

# Template engine (Docker Compose YAML)
tera = "1"

# Error handling
thiserror = "2"
anyhow = "1"

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
tracing-appender = "0.2"

# Validation
validator = { version = "0.19", features = ["derive"] }

# Security
secrecy = { version = "0.10", features = ["serde"] }
zeroize = "1"

# MCP protocol (JSON-RPC over stdio)
# No hay crate MCP oficial; se implementa manualmente con serde_json + tokio::io

# Utilities
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4"] }
colored = "3"
indicatif = "0.17"    # Progress bars
dialoguer = "0.11"    # Prompts interactivos
dirs = "6"            # Directorios del sistema

[dev-dependencies]
mockall = "0.13"       # Mocking para traits
tokio-test = "0.4"
tempfile = "3"
assert_cmd = "2"       # Test de CLI
predicates = "3"       # Assertions para CLI tests
```

**Total de dependencias directas: ~22** (comparado con 0 en PowerShell, pero cada una reemplaza funcionalidad que PS da gratis).

---

## 9. Concurrencia — operaciones paralelas

### 9.1 Ejemplo: deploy a multiples sitios

```rust
/* PowerShell: secuencial (~3 min por sitio × 5 = ~15 min) */
/* Rust: paralelo (~3 min para TODOS con semaforo de 3) */

pub async fn deploy_all(
    sites: &[SiteConfig],
    branch: &str,
    ssh: &impl SshExecutor,
    api: &impl InfraApi,
) -> Vec<Result<(), CoolifyError>> {
    let semaphore = Arc::new(Semaphore::new(3)); /* max 3 conexiones SSH simultaneas */

    let futures: Vec<_> = sites.iter().map(|site| {
        let sem = semaphore.clone();
        async move {
            let _permit = sem.acquire().await.unwrap();
            tracing::info!("Desplegando tema en '{}'", site.nombre);
            deploy_theme(site, branch, ssh, api).await
        }
    }).collect();

    futures::future::join_all(futures).await
}
```

### 9.2 Batch operations posibles

| Operacion                | PS actual     | Rust         |
| ------------------------ | ------------- | ------------ |
| Deploy 5 sitios          | ~15 min (sec) | ~3 min (par) |
| Habilitar cache en todos | ~2 min (sec)  | ~25s (par)   |
| Git status de todos      | ~50s (sec)    | ~10s (par)   |
| Restart de todos         | ~30s (sec)    | ~8s (par)    |
| Health check de todos    | ~60s (sec)    | ~12s (par)   |

---

## 10. Comparativa de seguridad

| Aspecto                     | PowerShell                              | Rust                                                |
| --------------------------- | --------------------------------------- | --------------------------------------------------- |
| **Buffer overflow**         | N/A (managed)                           | Imposible (ownership)                               |
| **Secrets en memoria**      | Strings normales, GC imprevisible       | `SecretString` + `Zeroize` (borrado deterministico) |
| **Command injection**       | Posible si se interpolan strings en SSH | `russh` usa canales binarios, no shell strings      |
| **Config secrets en disco** | `settings.json` con tokens en texto     | Env vars preferidas, config solo tiene `${VAR}`     |
| **TLS**                     | Depende de `Invoke-RestMethod`          | `rustls` (sin OpenSSL) con cert pinning posible     |
| **Credential lookup**       | `$env:VAR` + fallback a config          | `secrecy::SecretString` + zeroize al drop           |

---

## 11. Plan de migracion incremental

**No se necesita reescribir todo de golpe.** Se puede migrar modulo por modulo:

### Fase 1 — Core + MCP (2-3 semanas)

```
[X] Scaffold del proyecto con Cargo
[X] Config (figment + serde): settings.rs con validacion completa
[X] Logging (tracing + file rotation)
[X] Error types (thiserror)
[X] CLI basico con clap (solo --help y list)
[X] MCP server scaffold (initialize + tools/list)
```

**Resultado:** Binario que arranca en CLI y MCP mode, lee config, logea.

### Fase 2 — Infraestructura (2-3 semanas)

```
[ ] CoolifyApi client (reqwest)
[ ] SSH client (russh) con connection pooling
[ ] Docker operations sobre SSH
[ ] Template engine (tera) para Docker Compose
```

**Resultado:** Puede conectarse a Coolify API y ejecutar comandos SSH.

### Fase 3 — Comandos criticos (2-3 semanas)

```
[ ] list-sites (lectura de config + API status)
[ ] deploy-theme (SSH: git pull + build)
[ ] new-site (API: create stack + SSH: install theme)
[ ] Transaction/Rollback system
[ ] exec-command
[ ] view-logs
```

**Resultado:** Los 6 comandos mas usados funcionan. MCP tools para cada uno.

### Fase 4 — Comandos secundarios (1-2 semanas)

```
[ ] import-database / export-database
[ ] restart / redeploy
[ ] debug / cache
[ ] set-domain / git-status
[ ] setup-smtp
[ ] minecraft
```

**Resultado:** Paridad completa con PowerShell.

### Fase 5 — Mejoras Rust-only (1-2 semanas)

```
[ ] Operaciones paralelas (batch deploy, batch cache)
[ ] Health checks automaticos
[ ] Progress bars (indicatif) para operaciones largas
[ ] MCP resources (config viewer, log viewer)
[ ] MCP prompts (flujos guiados)
[ ] Tests de integracion completos
```

**Resultado:** Supera al PowerShell original en funcionalidad.

**Tiempo total estimado: 8-13 semanas.**

---

## 12. Riesgos y mitigaciones

| Riesgo                                | Probabilidad | Impacto | Mitigacion                                                                    |
| ------------------------------------- | ------------ | ------- | ----------------------------------------------------------------------------- |
| **russh es menos maduro que OpenSSH** | Media        | Alto    | Fallback a `tokio::process::Command("ssh", ...)` si russh falla en edge cases |
| **MCP protocol cambia**               | Baja         | Medio   | Implementacion manual (no depender de crate MCP third-party)                  |
| **Coolify API cambia en v5**          | Media        | Medio   | Trait `InfraApi` aisla el cambio a un solo archivo                            |
| **Tiempo de desarrollo alto**         | Media        | Alto    | Migracion incremental; PS sigue funcionando durante la transicion             |
| **Learning curve de Rust**            | Depende      | Medio   | El 80% del codigo es I/O async + serde, no Rust avanzado                      |
| **Windows line endings**              | Baja         | Bajo    | Eliminado: `russh` usa canales binarios, no text pipes                        |

---

## 13. Veredicto

### Es factible? — **SI, totalmente**

El proyecto coolify-manager es un **candidato ideal** para Rust por estas razones:

1. **Es I/O bound, no WP-coupled:** A diferencia de Glory (47% acoplado a WordPress), coolify-manager NO depende de WordPress en absoluto. Es un cliente SSH + HTTP puro. No hay funciones de WP que replicar.

2. **Tamano manejable:** ~4,700 LOC en PowerShell se traducen a ~6,000-8,000 LOC en Rust (mas tipos explitos, error handling, tests). Es un proyecto de tamano medio, no un megaproyecto.

3. **Ganancia clara en cada dimension:**
    - **Tipos**: Elimina BUG-01, BUG-03 y similares por definicion.
    - **Concurrencia**: Operaciones paralelas imposibles en PS 5.1.
    - **Portabilidad**: Binario unico para Linux/macOS/Windows.
    - **MCP**: Integracion nativa con VS Code sin intermediarios.
    - **Seguridad**: Secrets zeroized, sin command injection via SSH strings.
    - **Rollback**: Transacciones reversibles que no existian en PS.

4. **Sin dependencia de runtime:** El binario Rust es autocontenido. No requiere PowerShell, Python, ni ningun runtime instalado. Se puede copiar y ejecutar.

5. **MCP como diferenciador:** Convertir cada comando en un MCP tool transforma la herramienta de "script que se invoca manualmente" a "infraestructura que el agente de VS Code puede operar autonomamente". Esto es un salto cualitativo en productividad.

### Recomendacion

**Proceder con la reescritura en Rust**, siguiendo el plan incremental de 5 fases. Mantener el PowerShell funcional durante la transicion para que no haya downtime. Priorizar Fase 1 (Core + MCP) y Fase 2 (Infraestructura) porque desbloquean el valor mas rapido.

### Comparativa final

| Metrica                  | PowerShell actual | Rust propuesto                                      |
| ------------------------ | ----------------- | --------------------------------------------------- |
| **LOC**                  | ~4,700            | ~6,000-8,000                                        |
| **Type safety**          | Ninguna           | Total (compilador)                                  |
| **Error handling**       | Inconsistente     | Exhaustivo (Result)                                 |
| **Concurrencia**         | Ninguna           | async/await (tokio)                                 |
| **Portabilidad**         | Windows only      | Linux/macOS/Windows                                 |
| **MCP**                  | No existe         | Integrado                                           |
| **Startup**              | ~2s (interprete)  | <50ms (binario)                                     |
| **Dependencias runtime** | PowerShell 5.1    | Ninguna (binario estatico)                          |
| **Seguridad secrets**    | Strings en GC     | Zeroize deterministico                              |
| **Rollback**             | No existe         | Transacciones reversibles                           |
| **Tests**                | Pester (parcial)  | cargo test (compilador fuerza cobertura de errores) |
| **Deploy a N sitios**    | Secuencial        | Paralelo (semaforo)                                 |

---

_Estudio generado el 2026-03-05. Basado en analisis completo de los 30+ archivos del proyecto coolify-manager v2.0._
