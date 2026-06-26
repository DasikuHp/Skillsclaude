#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit|MultiEdit) — valida el .gd/.tscn recién editado
# y, si Godot lo rechaza, devuelve el error a Claude para que lo arregle (lazo automático).
#
# Diseño anti-falso-positivo: decide por TEXTO ('SCRIPT ERROR'/'Parse Error'), nunca por
# el exit code poco fiable de --check-only (GH-78587). No-op seguro si no hay 'godot' ni
# proyecto. Para desactivar el bloqueo: exporta GODOT_HOOK_DISABLE=1.
set -u
[ "${GODOT_HOOK_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$path" ] && exit 0
case "$path" in *.gd|*.tscn|*.tres) ;; *) exit 0 ;; esac

GODOT="${GODOT_BIN:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || exit 0   # sin godot en PATH: no-op

# Sube hasta la raíz del proyecto (project.godot).
dir=$(dirname "$path"); proj=""
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  [ -f "$dir/project.godot" ] && { proj="$dir"; break; }
  dir=$(dirname "$dir")
done
[ -z "$proj" ] && exit 0   # no es un proyecto Godot

# Validador fiable del proyecto si existe; si no, --check-only del archivo.
if [ -f "$proj/ci/validate_all.gd" ]; then
  out=$("$GODOT" --headless --path "$proj" --script res://ci/validate_all.gd 2>&1)
else
  rel=${path#"$proj"/}
  out=$("$GODOT" --headless --path "$proj" --check-only --script "res://$rel" 2>&1)
fi

errs=$(printf '%s' "$out" | grep -iE 'SCRIPT ERROR|Parse Error|Compile Error|Nonexistent function' | head -6)
[ -z "$errs" ] && exit 0   # compila: silencioso

# Enriquecer con errors.json (mensaje conocido -> fix + reference).
HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
hint=""
if [ -f "$HOOK_DIR/errors.json" ]; then
  hint=$(jq -r --arg e "$errs" '
    [ .[] | select(($e|ascii_downcase) | contains(.match|ascii_downcase)) ]
    | (.[0] // empty) | if . then "FIX: \(.fix) (ver \(.reference))" else empty end' \
    "$HOOK_DIR/errors.json" 2>/dev/null)
fi

{
  echo "Godot rechazó el script recién editado ($path):"
  printf '%s\n' "$errs"
  [ -n "$hint" ] && echo "$hint"
  echo "Corrígelo antes de seguir. (Si es 'Could not find base class'/'Unrecognized UID' en un checkout limpio, es CACHÉ: corre la fase 0 'godot --headless --import --quit-after 2'.)"
} >&2
exit 2
