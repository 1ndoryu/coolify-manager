# Problema de Ramas Divergentes en Coolify Manager

## Descripción del Problema
Al intentar actualizar el tema Glory mediante `manager.ps1 deploy -Update`, se produjo un error de Git bloqueante:

```
[INFO] Actualizando tema principal...
hint: You have divergent branches and need to specify how to reconcile them.
...
fatal: Need to specify how to reconcile divergent branches.
```

## Causa
Git (versiones recientes) requiere una configuración explícita sobre cómo manejar "ramas divergentes" (cuando la rama local y la remota han avanzado de forma diferente). Por defecto no toma ninguna acción y falla si no está configurado `pull.rebase` o `pull.ff`.

El script `ThemeManager.psm1` ejecutaba `git pull` sin ninguna configuración previa en el entorno del contenedor, lo que provocaba este fallo cuando existía divergencia en el historial.

## Solución Implementada
Se ha modificado la función `Update-GloryTheme` en `modules/WordPress/ThemeManager.psm1` para configurar Git globalmente dentro del contenedor antes de realizar operaciones de actualización.

Se añadieron las siguientes configuraciones al script temporal:
1. `git config --global pull.rebase false`: Configura la estrategia de merge por defecto (crear un merge commit si es necesario), que es el comportamiento estándar esperado.
2. Identidad de Git genérica (`user.name` y `user.email`) para permitir que Git cree commits de merge automáticamente si fuera necesario sin fallar por falta de identidad.

Esto asegura que `git pull` pueda reconciliar las ramas automáticamente mediante un merge commit, o simplemente avanzar si es un fast-forward, sin detener el proceso de despliegue.
