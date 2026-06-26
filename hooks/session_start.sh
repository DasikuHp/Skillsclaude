#!/usr/bin/env bash
# SessionStart hook — orienta a Claude y calienta el proyecto Godot (su stdout = contexto).
set -u
GODOT="${GODOT_BIN:-godot}"
if [ -f project.godot ]; then
  if command -v "$GODOT" >/dev/null 2>&1; then
    "$GODOT" --headless --import --quit-after 2 >/dev/null 2>&1 || true
    echo "[godot-46-rpg] Proyecto Godot detectado; caché de imports (.godot/) calentada."
  else
    echo "[godot-46-rpg] AVISO: 'godot' no está en PATH; el lazo de verificación headless no podrá ejecutarse (instala Godot 4.6 o exporta GODOT_BIN)."
  fi
fi
# Sondeo de backend MCP (Summer stdio/:6550 vs Godot AI HTTP vs headless) -> .claude/mcp_backend
backend="headless"
if [ -f "$HOME/.summer/api-token" ] && command -v curl >/dev/null 2>&1 && \
   curl -fsS -m 2 "http://127.0.0.1:${SUMMER_API_PORT:-6550}/" >/dev/null 2>&1; then
  backend="summer"
fi
[ -d .claude ] && printf '%s\n' "$backend" > .claude/mcp_backend 2>/dev/null || true
echo "[godot-46-rpg] Backend MCP detectado: $backend (summer = editor vivo; headless = lazo por CLI). Ver references/30-mcp-routing-loop.md."

echo "[godot-46-rpg] Skill activa. Entra por SKILL.md, usa el dispatcher tema→archivo, y CIERRA EL LAZO (verify_loop.sh o el MCP) tras cada edición. Un verbo a la vez, un play, un vistazo. Ponytail: reusar nodos/Resources nativos; con Summer presente, delega en sus skills/tools y no reimplementes."
exit 0
