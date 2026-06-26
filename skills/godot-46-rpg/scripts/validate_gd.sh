#!/usr/bin/env bash
# validate_gd.sh — valida la sintaxis de UN script .gd por CLI, con exit code fiable.
# Uso: bash scripts/validate_gd.sh res://scripts/player.gd   (ejecútalo desde la raíz del proyecto Godot)
#
# CAVEAT (por qué NO confiamos en $? de --check-only):
#   El exit code de --check-only es históricamente poco fiable (GH-33895/54087/85062) y
#   da FALSOS POSITIVOS cuando el script depende de autoloads que aún no se registraron
#   (GH-78587, mitigado por PR #110295 en 4.6). Por eso decidimos por TEXTO: grep de
#   'SCRIPT ERROR'/'Parse Error' en la salida. Para validar TODOS los .gd con exit code
#   fiable, usa scripts/validate_all.gd (controla su propio quit(N)).
set -u
GODOT="${GODOT_BIN:-godot}"
SCRIPT="${1:?Uso: validate_gd.sh res://ruta/al/script.gd}"

out=$("$GODOT" --headless --path . --check-only --script "$SCRIPT" 2>&1)
echo "$out"
if echo "$out" | grep -qiE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'; then
  echo "FAIL: error de parseo en $SCRIPT"
  exit 1
fi
echo "OK: $SCRIPT compila"
