#!/usr/bin/env bash
# smoke_test.sh — ¿el juego ARRANCA de verdad? (compilar != bootear). Godot 4.6, headless.
# Uso: bash scripts/smoke_test.sh   (desde la raíz del proyecto Godot)
#
# Arranca autoloads + escena principal, corre N frames y sale. timeout + </dev/null son
# OBLIGATORIOS: ante un error de runtime headless cae a un prompt de debugger que espera
# stdin para siempre y colgaría el CI (y a una IA que no ve nada).
set -u
GODOT="${GODOT_BIN:-godot}"
FRAMES="${1:-90}"
TIMEOUT="${2:-120}"

out=$(timeout "$TIMEOUT" "$GODOT" --headless --path . --quit-after "$FRAMES" </dev/null 2>&1)
rc=$?
echo "$out"
if [ "$rc" = "124" ]; then echo "BOOT HANG (timeout ${TIMEOUT}s) — probable bucle o break de debugger"; exit 1; fi
if echo "$out" | grep -qiE 'SCRIPT ERROR|Cannot call method|Nonexistent function|Invalid (get|set|call)|^ERROR:'; then
  echo "BOOT FAILED — error en _ready() de un autoload o en la escena principal"; exit 1
fi
echo "BOOT OK"
