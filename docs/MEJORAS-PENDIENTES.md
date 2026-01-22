# Mejoras Pendientes - Coolify Manager

> **Última actualización:** 2026-01-21  
> **Contexto:** Problemas detectados durante el despliegue de `cap.wandori.us`

---

## Resumen de Problemas

Durante el despliegue del sitio CAP se identificaron varios pasos que requirieron intervención manual, lo que ralentiza el proceso y complica el flujo de trabajo.

---

## 1. Comando `new` Incompleto

### Problema
El comando `new-site.ps1` falla en el paso 3 (instalación del tema) con el error:
```
A parameter cannot be found that matches parameter name 'StackName'.
```

### Impacto
- El stack se crea correctamente en Coolify
- El tema NO se instala automáticamente
- Se debe ejecutar `deploy` manualmente después

### Solución Propuesta
- Revisar los parámetros pasados a `Install-GloryTheme` en `new-site.ps1`
- El parámetro debería ser `StackUuid` o similar, no `StackName`
- Agregar el sitio automáticamente a `settings.json` después de crear el stack

---

## 2. Configuración de URLs de WordPress

### Problema
Después de crear el stack, WordPress queda configurado con URLs por defecto (localhost o IP), no con el dominio configurado en Coolify.

### Pasos Manuales Actuales
1. Ir al panel de WordPress → Ajustes → Generales
2. Cambiar "Dirección de WordPress" y "Dirección del sitio" al dominio correcto
3. Reiniciar el stack desde Coolify

### Solución Propuesta
Agregar al comando `new` un paso automático que:
```php
update_option('siteurl', 'https://DOMINIO');
update_option('home', 'https://DOMINIO');
```

O crear un nuevo comando:
```powershell
.\manager.ps1 set-url -SiteName "cap" -Domain "https://cap.wandori.us"
```

---

## 3. Activación del Tema

### Problema
Después de instalar el tema Glory, este no se activa automáticamente. El tema por defecto de WordPress sigue activo.

### Pasos Manuales Actuales
1. Ir a WordPress → Apariencia → Temas
2. Activar el tema "Glory" manualmente

### Solución Propuesta
Agregar al final de `Install-GloryTheme` o `deploy-theme.ps1`:
```php
switch_theme('glory');
```

---

## 4. Comando `exec` con Problemas de Parsing

### Problema
El comando `exec` tiene problemas al parsear argumentos con espacios, guiones o caracteres especiales:
```powershell
.\manager.ps1 exec -SiteName "cap" -Command "ls -la /var/www/html"
# Error: A parameter cannot be found that matches parameter name 'la'.
```

### Impacto
- No se pueden ejecutar comandos bash complejos
- No se puede ejecutar código PHP con paréntesis/comillas

### Solución Propuesta
- Revisar el parsing de argumentos en `exec-command.ps1`
- Usar `$args` o `ValueFromRemainingArguments` para capturar todo el comando
- Escapar correctamente las comillas al construir el comando SSH

---

## 5. Agregar Sitio a settings.json Automáticamente

### Problema
Después de crear un stack con `new`, el sitio NO se agrega automáticamente a `config/settings.json`.

### Pasos Manuales Actuales
1. Copiar el `stackUuid` del output
2. Editar `settings.json` manualmente
3. Agregar el nuevo sitio con todos sus campos

### Solución Propuesta
Al final de `new-site.ps1`, agregar lógica para:
1. Leer el JSON actual
2. Agregar el nuevo sitio al array `sitios`
3. Guardar el JSON actualizado

---

## 6. Flujo Ideal Post-Mejoras

Una vez implementadas las mejoras, el flujo debería ser:

```powershell
# Un solo comando hace todo
.\manager.ps1 new -SiteName "cap" -Domain "https://cap.wandori.us" -GloryBranch "glory-react-calendarioesc"
```

**Pasos automáticos:**
1. ✅ Crear stack en Coolify (WordPress + MariaDB)
2. ✅ Esperar a que los contenedores inicien
3. 🔧 Configurar URLs de WordPress automáticamente
4. ✅ Instalar tema Glory (clonar, composer, npm, build)
5. 🔧 Activar tema Glory automáticamente
6. 🔧 Agregar sitio a `settings.json`
7. ✅ Mostrar resumen y credenciales

**Leyenda:** ✅ Ya funciona | 🔧 Necesita implementar

---

## 7. Mejoras Secundarias

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
