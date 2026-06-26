---
description: Crea un proyecto RPG 3D mínimo y arrancable en Godot 4.6 (scaffolder de la skill)
argument-hint: "<nombre> <desktop|mobile|web>"
allowed-tools: Bash, Read
---

Genera un proyecto Godot 4.6 listo para jugar con el scaffolder de la skill (renderer por target, Jolt, 3 autoloads, lazo de verificación incluido).

!bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/godot-46-rpg/scripts/new_project.sh" "$1" "$2"

Después:
- Confirma la estructura creada y recuerda que `verify_loop.sh` ya viene dentro del proyecto.
- Si target=web, recuerda: Compatibility y SIN C#.
- Lee `skills/godot-46-rpg/SKILL.md` y usa el dispatcher para añadir sistemas (`/godot-add`).
