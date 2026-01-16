# Plan: Configuración de Cache Headers para Sitios WordPress

## Problema

Los sitios WordPress desplegados en Coolify no tienen configurados los headers de caché HTTP para archivos estáticos. Esto resulta en:

- **TTL en caché: None** para todos los assets (JS, CSS, imágenes, fuentes)
- Lighthouse reporta "Usa tiempos de almacenamiento en caché eficientes"
- Los usuarios descargan los mismos archivos en cada visita
- Mayor consumo de ancho de banda y tiempos de carga más lentos

### Archivos afectados típicos

| Tipo       | Extensiones                     | Tamaño típico |
| ---------- | ------------------------------- | ------------- |
| JavaScript | `.js`                           | 30-50 KiB     |
| CSS        | `.css`                          | 10-40 KiB     |
| Fuentes    | `.woff2`, `.woff`, `.ttf`       | 15-25 KiB     |
| Imágenes   | `.jpg`, `.png`, `.svg`, `.webp` | 5-50 KiB      |
| Favicon    | `.ico`, `.svg`                  | 1-5 KiB       |

---

## Solución Propuesta

### Enfoque: Modificar `.htaccess` en el contenedor WordPress

Los contenedores WordPress de Coolify usan Apache, por lo que la solución más simple y efectiva es agregar reglas de caché al archivo `.htaccess`.

### Headers recomendados

```apache
# =============================================================================
# CACHE HEADERS - Generado por Coolify Manager
# =============================================================================

<IfModule mod_expires.c>
    ExpiresActive On
    
    # Imágenes: 1 año (inmutables o versionadas)
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    
    # Fuentes: 1 año
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
    ExpiresByType application/font-woff2 "access plus 1 year"
    ExpiresByType application/font-woff "access plus 1 year"
    
    # CSS y JS: 1 mes (WordPress agrega ?ver= para cache busting)
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    
    # HTML: no cachear (contenido dinámico)
    ExpiresByType text/html "access plus 0 seconds"
</IfModule>

<IfModule mod_headers.c>
    # Archivos estáticos con cache-control
    <FilesMatch "\.(ico|pdf|jpg|jpeg|png|gif|webp|svg|js|css|woff|woff2|ttf)$">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </FilesMatch>
    
    # HTML sin caché
    <FilesMatch "\.(html|htm|php)$">
        Header set Cache-Control "no-cache, no-store, must-revalidate"
    </FilesMatch>
</IfModule>
```

---

## Plan de Implementación

### Fase 1: Comando `cache` para el CLI

Crear un nuevo comando `cache-site.ps1` que:

1. **Verificar estado actual**
   ```powershell
   .\manager.ps1 cache -SiteName padel -Status
   ```
   - Lee el `.htaccess` actual
   - Detecta si ya tiene reglas de caché
   - Muestra un resumen

2. **Habilitar caché**
   ```powershell
   .\manager.ps1 cache -SiteName padel -Enable
   ```
   - Hace backup del `.htaccess` actual
   - Agrega las reglas de caché al inicio del archivo
   - Verifica que Apache las acepta (`apachectl configtest`)

3. **Deshabilitar caché**
   ```powershell
   .\manager.ps1 cache -SiteName padel -Disable
   ```
   - Remueve las reglas agregadas por el CLI
   - Mantiene las reglas originales de WordPress

### Fase 2: Integración con `new-site.ps1`

Modificar el comando `new` para que:

1. Después de crear el stack y desplegar el tema
2. Ejecute automáticamente `cache -Enable`
3. Agregue un flag opcional `-SkipCache` para omitir

```powershell
.\manager.ps1 new -SiteName blog -Domain "https://blog.com"
# Automáticamente habilita caché

.\manager.ps1 new -SiteName blog -Domain "https://blog.com" -SkipCache
# Crea sin configurar caché
```

### Fase 3: Comando `cache -All`

Para aplicar a todos los sitios existentes:

```powershell
.\manager.ps1 cache -All -Enable
```

---

## Estructura de Archivos

```
commands/
├── cache-site.ps1       # Nuevo comando principal
└── ...

modules/
└── WordPress/
    └── CacheManager.psm1  # Nuevo módulo con funciones:
        - Get-CacheStatus
        - Enable-CacheHeaders
        - Disable-CacheHeaders
        - Test-HtaccessValid
```

---

## Detalles Técnicos

### Script PHP para modificar .htaccess

Para evitar problemas de escape en SSH, el CLI puede:

1. Crear un script PHP temporal en el contenedor
2. Ejecutarlo con `php /tmp/cache-config.php`
3. El script PHP modifica el `.htaccess` de forma segura

```php
<?php
$htaccessPath = '/var/www/html/.htaccess';
$cacheRules = <<<'CACHE'
# === COOLIFY MANAGER CACHE START ===
<IfModule mod_expires.c>
    // ... reglas ...
</IfModule>
# === COOLIFY MANAGER CACHE END ===
CACHE;

$current = file_exists($htaccessPath) ? file_get_contents($htaccessPath) : '';

// Verificar si ya existe
if (strpos($current, 'COOLIFY MANAGER CACHE') !== false) {
    echo "ALREADY_CONFIGURED";
    exit(0);
}

// Agregar al inicio (después de las reglas de WordPress si existen)
$new = $cacheRules . "\n\n" . $current;
file_put_contents($htaccessPath, $new);
echo "SUCCESS";
```

### Verificación de módulos Apache

El script debe verificar que `mod_expires` y `mod_headers` estén habilitados:

```bash
apache2ctl -M | grep -E "(expires|headers)_module"
```

Si no están habilitados, el CLI debe:
1. Intentar habilitarlos: `a2enmod expires headers`
2. Reiniciar Apache: `apache2ctl graceful`
3. O informar al usuario que debe hacerlo manualmente

---

## Prioridad y Estimación

| Tarea                 | Prioridad | Complejidad | Tiempo estimado |
| --------------------- | --------- | ----------- | --------------- |
| `cache -Status`       | Alta      | Baja        | 1 hora          |
| `cache -Enable`       | Alta      | Media       | 2 horas         |
| `cache -Disable`      | Media     | Baja        | 30 min          |
| Integración con `new` | Media     | Baja        | 30 min          |
| `cache -All`          | Baja      | Baja        | 30 min          |
| Documentación         | Media     | Baja        | 30 min          |

**Total estimado: 5 horas**

---

## Consideraciones

### Cache Busting

WordPress ya maneja cache busting con el parámetro `?ver=`:
- `init.css?ver=0.1.9`
- `amazon-product.js?ver=1763...`

Esto significa que podemos usar tiempos de caché largos (1 año) porque cuando el archivo cambia, la URL también cambia.

### Imágenes subidas

Las imágenes en `/wp-content/uploads/` también se benefician de caché larga. WordPress genera URLs únicas para cada imagen.

### CDN (futuro)

Si en el futuro se agrega un CDN (Cloudflare, etc.), estas reglas seguirán funcionando como fallback para requests que lleguen directamente al origen.

---

## Estado

- [x] Fase 1: Comando `cache` (completado)
  - [x] `cache -Status` - Verificar estado de cache headers
  - [x] `cache -Enable` - Habilitar cache headers  
  - [x] `cache -Disable` - Deshabilitar cache headers
  - [x] `cache -All` - Aplicar a todos los sitios
  - [x] Módulo `CacheManager.psm1` creado
- [x] Fase 2: Integración con `new`
  - [x] Parámetro `-SkipCache` agregado a `new-site.ps1`
  - [x] Cache headers se habilitan automáticamente al crear sitios
  - [x] Importación de módulos `CacheManager.psm1` y `SshOperations.psm1`
- [x] Documentación en README.md
