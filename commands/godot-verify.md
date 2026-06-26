---
description: Corre el lazo de verificación headless del proyecto Godot actual y resume el resultado
allowed-tools: Bash
---

!bash verify_loop.sh

Resume:
- Si aparece `SCRIPT ERROR`/`Parse Error`: indica archivo:línea y el fix (consulta `references/13-common-errors-unstuck.md` o `hooks/errors.json`). NO trates "Could not find base class"/"Unrecognized UID" como bug: es caché → corre la fase 0 (`godot --headless --import --quit-after 2`).
- Si pasa: di "verde" y continúa.
