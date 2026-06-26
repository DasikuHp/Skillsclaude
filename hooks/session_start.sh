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
echo "[godot-46-rpg] Skill activa. Entra por SKILL.md, usa el dispatcher tema→archivo, y CIERRA EL LAZO (verify_loop.sh) tras cada edición. Filosofía ponytail: reusar nodos/Resources nativos antes que escribir arquitectura propia."
exit 0
