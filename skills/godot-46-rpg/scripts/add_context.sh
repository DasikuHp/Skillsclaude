#!/usr/bin/env bash
# add_context.sh — inyecta el contexto de la skill (CLAUDE.md + .claude/ con hooks+settings)
# en un proyecto Godot/Summer YA EXISTENTE, sin tocar su contenido. Componible con Summer:
#   npx -y summer-engine@latest create 3d-basic MiRPG && bash add_context.sh MiRPG summer
# Ponytail: no duplica el scaffold de Summer; solo añade el lazo de la skill encima.
set -euo pipefail

DEST="${1:?Uso: add_context.sh <dir_proyecto_existente> [backend: summer|godot-ai|headless]}"
BACKEND="${2:-summer}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

[ -d "$DEST" ] || { echo "ERROR: '$DEST' no existe"; exit 1; }

mkdir -p "$DEST/.claude/hooks" "$DEST/ci"
cp "$PLUGIN_ROOT/hooks/validate_gd_post_edit.sh" "$PLUGIN_ROOT/hooks/session_start.sh" "$PLUGIN_ROOT/hooks/errors.json" "$DEST/.claude/hooks/" 2>/dev/null || true
cp "$SKILL_DIR/scripts/validate_all.gd" "$DEST/ci/validate_all.gd" 2>/dev/null || true
cp "$SKILL_DIR/scripts/verify_loop.sh" "$SKILL_DIR/scripts/smoke_test.sh" "$SKILL_DIR/scripts/validate_gd.sh" "$DEST/" 2>/dev/null || true
chmod +x "$DEST/.claude/hooks/"*.sh "$DEST/"*.sh 2>/dev/null || true
printf '%s\n' "$BACKEND" > "$DEST/.claude/mcp_backend"

cat > "$DEST/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit|MultiEdit",
        "hooks": [ { "type": "command", "command": "bash .claude/hooks/validate_gd_post_edit.sh", "timeout": 30 } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash .claude/hooks/session_start.sh" } ] }
    ]
  }
}
JSON

cat > "$DEST/CLAUDE.md" <<MD
# $(basename "$DEST") — proyecto Godot 4.6 / Summer (RPG, ponytail)

- **Skill**: \`godot-46-rpg\`. Entra por su \`SKILL.md\` + dispatcher; con Summer presente, delega en sus skills/tools (no reimplementes).
- **Backend MCP**: $BACKEND (ver references/30-mcp-routing-loop.md). \`summer\` = editor vivo; si no, lazo headless por \`scripts/\`.
- **Lazo**: un verbo a la vez → play → vistazo. Tras cada edición un hook valida los \`.gd\` y te devuelve el error. \`bash verify_loop.sh\` para el lazo headless.
- **Ponytail / lazy-not-negligent**: reusa nodos/Resources nativos; nunca recortes validación/errores/seguridad/accesibilidad.
MD
echo "Contexto de la skill inyectado en '$DEST' (backend=$BACKEND): CLAUDE.md + .claude/ + lazo."
