#!/usr/bin/env bash
# Lazo de auto-verificacion headless para una IA que no ve el editor (Godot 4.6).
set -u
export GODOT_DISABLE_LEAK_CHECKS=1

# FASE 0: warm-up de imports (NUNCA --quit; usa --quit-after 2). Caso #1 de atascos.
godot --headless --path . --import --quit-after 2 --verbose
# Segunda pasada resuelve warnings residuales de uid:// (no es codigo roto).
godot --headless --path . --import --quit-after 2 >/dev/null 2>&1

# FASE 1: validar sintaxis con exit code FIABLE (tool script propio).
godot --headless --path . --script res://ci/validate_all.gd
if [ $? -ne 0 ]; then echo "SYNTAX FAIL"; exit 1; fi

# FASE 2: smoke test. timeout + </dev/null evitan el debugger interactivo invisible.
out=$(timeout 120 godot --headless --path . --quit-after 90 </dev/null 2>&1)
rc=$?
echo "$out"
if [ "$rc" = "124" ]; then echo "BOOT HANG (timeout)"; exit 1; fi
if echo "$out" | grep -qiE 'SCRIPT ERROR|Cannot call method|Nonexistent function|^ERROR:'; then
  echo "BOOT FAILED"; exit 1
fi

# FASE 3: tests con exit code FIABLE (GUT -gexit).
timeout 300 godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit </dev/null
echo "tests exit=$?"
