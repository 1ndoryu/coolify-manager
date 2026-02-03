# Mejoras Pendientes - Coolify Manager

> **Última actualización:** 2026-02-03  
> **Contexto:** Problemas detectados durante el despliegue de `cap.wandori.us`  
> **Estado:** ✅ TODAS LAS MEJORAS PRINCIPALES IMPLEMENTADAS

---

## Resumen de Mejoras Implementadas

Todas las mejoras principales han sido implementadas y probadas con un servidor de prueba (`test-mejoras.wandori.us`).

---

## 1. ✅ Comando `new` - SOLUCIONADO

### Problema Original
El comando `new-site.ps1` fallaba con el error de parámetro `StackName`.

### Solución Implementada
- Corregido `new-site.ps1` para usar `StackUuid` en lugar de `StackName`
- El tema ahora se instala correctamente usando `Install-GloryTheme -StackUuid $stackResult.uuid`

**Archivo modificado:** [new-site.ps1](../commands/new-site.ps1)

---

## 2. ✅ Configuración de URLs de WordPress - SOLUCIONADO

### Problema Original
WordPress quedaba configurado con URLs por defecto (localhost o IP).

### Solución Implementada
- `Set-WordPressUrls` ahora acepta `StackUuid` como parámetro preferido
- Se llama automáticamente después de crear el stack con el dominio correcto

**Archivo modificado:** [SiteManager.psm1](../modules/WordPress/SiteManager.psm1)

---

## 3. ✅ Activación del Tema - SOLUCIONADO

### Problema Original
El tema Glory no se activaba automáticamente después de instalarlo.

### Solución Implementada
- Nueva función `Enable-GloryTheme` que ejecuta `switch_theme()` en WordPress
- Se llama automáticamente desde `new-site.ps1` después de instalar el tema
- Incluye supresión de warnings de CLI (HTTP_HOST no definido)

**Archivo modificado:** [SiteManager.psm1](../modules/WordPress/SiteManager.psm1), [new-site.ps1](../commands/new-site.ps1)

---

## 4. ✅ Comando `exec` con Problemas de Parsing - SOLUCIONADO

### Problema Original
```powershell
.\manager.ps1 exec -SiteName "cap" -Command "ls -la /var/www/html"
# Error: A parameter cannot be found that matches parameter name 'la'.
```

### Solución Implementada
- Agregado parámetro `RawArgs` con `ValueFromRemainingArguments` para capturar argumentos extra
- Mejorado el manejo de comandos PHP usando archivos temporales en lugar de `php -r`
- Corregido el escape de comillas en `manager.ps1 > Invoke-CommandScript`

**Archivos modificados:** [exec-command.ps1](../commands/exec-command.ps1), [manager.ps1](../manager.ps1)

---

## 5. ✅ Agregar Sitio a settings.json - YA FUNCIONABA

### Estado
Esta funcionalidad ya estaba implementada correctamente en `new-site.ps1`.
El sitio se agrega automáticamente al array `sitios` después de crear el stack.

---

## 6. ✅ Flujo Ideal - IMPLEMENTADO

El flujo ahora funciona completamente con un solo comando:

```powershell
.\manager.ps1 new -SiteName "mi-sitio" -Domain "https://mi-sitio.wandori.us" -GloryBranch "main"
```

**Pasos automáticos:**
1. ✅ Crear stack en Coolify (WordPress + MariaDB)
2. ✅ Esperar a que los contenedores inicien
3. ✅ Configurar URLs de WordPress automáticamente
4. ✅ Instalar tema Glory (clonar, composer, npm, build)
5. ✅ Activar tema Glory automáticamente
6. ✅ Agregar sitio a `settings.json`
7. ✅ Mostrar resumen y credenciales

---

## 7. Mejoras Secundarias (Pendientes)

### 7.1 Validación de Dominio Pre-Despliegue
Verificar que el dominio apunte al VPS antes de configurar HTTPS.

### 7.2 Credenciales de Admin
El comando `new` debería mostrar o crear credenciales de admin de WordPress.

### 7.3 Logs más Claros
Mejorar los mensajes de progreso para indicar claramente qué paso está ejecutando.

### 7.4 Rollback en Caso de Error
Si falla un paso, limpiar los recursos creados (stack, contenedores).

---

## Prioridad de Implementación

| #   | Mejora                               | Esfuerzo | Impacto |
| --- | ------------------------------------ | -------- | ------- |
| 1   | Arreglar parámetro en `new-site.ps1` | Bajo     | Alto    |
| 2   | Activar tema automáticamente         | Bajo     | Alto    |
| 3   | Configurar URLs automáticamente      | Medio    | Alto    |
| 4   | Agregar sitio a settings.json        | Medio    | Alto    |
| 5   | Arreglar comando `exec`              | Medio    | Medio   |

---

## Notas del Despliegue CAP

**Fecha:** 2026-01-21  
**Sitio:** cap.wandori.us  
**Stack UUID:** `qgskgw8wwc08o444o08wko8o`  
**Branch:** `glory-react-calendarioesc`  

**Pasos manuales realizados:**
1. Ejecutar `deploy` después de `new` (porque falló la instalación del tema)
2. Cambiar URLs en WordPress manualmente
3. Activar tema Glory manualmente
4. Reiniciar stack

**Tiempo total:** ~25 minutos (debería ser ~5 minutos con automatización completa)

---

## Prueba de Mejoras - 2026-02-03

**Sitio de prueba:** test-mejoras.wandori.us  
**Stack UUID:** `e4ccskg4ssscsgw00g4o408s`  
**Branch:** `main`  

**Resultado del test:**
- ✅ Stack creado correctamente
- ✅ Tema instalado automáticamente (composer + npm)
- ✅ Función `Enable-GloryTheme` ejecutada
- ✅ URLs configuradas automáticamente
- ✅ Sitio agregado a `settings.json`
- ✅ Comando `exec` funciona con argumentos complejos (`ls -la`)

**Tiempo total:** ~3-4 minutos (automatizado completamente)
