# Plan de Mejora: Diagnóstico y Resolución de Conflictos Git

## 1. El Problema Actual
El CLI `manager.ps1` tiene dificultades para ejecutar comandos complejos de bash (encadenados con `&&`, pipes, comillas) a través de `exec`, debido a problemas de escaping entre PowerShell -> SSH -> Docker -> Bash.

Esto impide diagnosticar correctamente el estado del repositorio (`git status`, ramas actuales) cuando ocurren conflictos de merge como el reportado en el sitio `guillermo`.

## 2. Solución Propuesta

### Fase A: Comando de Diagnóstico Dedicado
En lugar de pasar comandos arbitrarios por string, crearemos un comando específico `git-status` que utilice la técnica de "Script Temporal" (ya implementada en `Invoke-DockerExec` para scripts largos) para garantizar la ejecución fiel.

**Nuevo comando:** `.\manager.ps1 git-status -SiteName guillermo`

**Funcionamiento interno:**
1. Generará un script bash temporal con:
   ```bash
   cd /var/www/html/wp-content/themes/$THEME
   echo "=== GIT BRANCH ==="
   git branch -vv
   echo "=== GIT STATUS ==="
   git status --short
   echo "=== GIT REMOTE ==="
   git remote -v
   ```
2. Copiará y ejecutará este script en el contenedor.
3. Mostrará el output limpio.

### Fase B: Modo "Force" en Despliegue
Los conflictos de merge en un entorno de producción/staging (como el contenedor) suelen deberse a cambios locales accidentales o archivos generados que no deberían estar ahí. Intentar hacer merge (`git pull`) no es la estrategia correcta para despliegues; lo correcto es sobreescribir para igualar al repositorio.

**Mejora en `deploy-theme.ps1`:**
Añadir flag `-Force` o `-Reset` que cambie la estrategia de actualización:

**De (Actual):**
```bash
git pull
```

**A (Con Force):**
```bash
git fetch --all
git reset --hard origin/$BRANCH
git clean -fd  # Opcional, para borrar archivos no trackeados
```

## 3. Pasos de Implementación
1.  Crear `commands/git-status.ps1`.
2.  Probar el diagnóstico en el sitio `guillermo`.
3.  Modificar `modules/WordPress/ThemeManager.psm1` para soportar el modo `Force`.
4.  Modificar `commands/deploy-theme.ps1` para exponer el argumento `-Force`.
5.  Ejecutar el despliegue forzado para arreglar el sitio.
