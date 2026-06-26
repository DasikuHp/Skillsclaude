#!/usr/bin/env bash
# new_project.sh — scaffolder de un proyecto RPG 3D mínimo y ARRANCABLE en Godot 4.6 (ponytail).
# Uso: bash scripts/new_project.sh <nombre> <desktop|mobile|web> [dir_destino]
# Crea: estructura de carpetas, project.godot (renderer por target + Jolt), .gitignore/.gitattributes,
#       3 autoloads de servicios (Settings/SaveSystem/EventBus), una escena principal vacía, git init.
# Cierra con un warm-up de imports si 'godot' está en PATH.
set -euo pipefail

NAME="${1:?Uso: new_project.sh <nombre> <desktop|mobile|web> [dir]}"
TARGET="${2:?target requerido: desktop | mobile | web}"
DEST="${3:-$NAME}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"

case "$TARGET" in
  desktop) RM="forward_plus"; FEAT="Forward Plus" ;;
  mobile)  RM="mobile";       FEAT="Mobile" ;;
  web)     RM="gl_compatibility"; FEAT="GL Compatibility"
           echo "AVISO: target web ⇒ renderer Compatibility y SIN C#. Usa GDScript." ;;
  *) echo "target inválido: $TARGET (usa desktop|mobile|web)"; exit 1 ;;
esac

if [ -e "$DEST" ]; then echo "ERROR: '$DEST' ya existe"; exit 1; fi
mkdir -p "$DEST"/{scenes,scripts,autoload,resources,assets,test,ci}

# Herramientas de verificación headless DENTRO del proyecto (lazo edito→compruebo→corrijo).
cp "$SKILL_DIR/scripts/validate_all.gd" "$DEST/ci/validate_all.gd"
cp "$SKILL_DIR/scripts/verify_loop.sh" "$SKILL_DIR/scripts/smoke_test.sh" "$SKILL_DIR/scripts/validate_gd.sh" "$DEST/"
chmod +x "$DEST"/*.sh

# project.godot desde la plantilla (sustitución de placeholders)
sed -e "s/__PROJECT_NAME__/${NAME//\//_}/g" \
    -e "s/__RENDERING_METHOD__/$RM/g" \
    -e "s/__FEATURES__/$FEAT/g" \
    "$SKILL_DIR/assets/project.godot.tmpl" > "$DEST/project.godot"

cp "$SKILL_DIR/assets/gitignore.tmpl"     "$DEST/.gitignore"
cp "$SKILL_DIR/assets/gitattributes.tmpl" "$DEST/.gitattributes"

# Tres autoloads de servicios reales (no un GameManager-dios).
cat > "$DEST/autoload/settings.gd" <<'GD'
extends Node
## Settings — preferencias persistentes (ponytail: usa ConfigFile, no inventes formato).
const PATH := "user://settings.cfg"
var _cfg := ConfigFile.new()

func _ready() -> void:
	_cfg.load(PATH)  # ok si no existe aún

func get_value(section: StringName, key: StringName, default: Variant = null) -> Variant:
	return _cfg.get_value(section, key, default)

func set_value(section: StringName, key: StringName, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	_cfg.save(PATH)
GD

cat > "$DEST/autoload/save_system.gd" <<'GD'
extends Node
## SaveSystem — guarda datos planos (ids, no objetos) a user://. Valida al cargar (lazy != negligente).
const PATH := "user://save.json"

func save_game(data: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("save_game: no se pudo abrir %s" % PATH); return
	f.store_string(JSON.stringify(data))

func load_game() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:  # save corrupto: no crashees
		push_warning("load_game: save inválido, empiezo en limpio")
		return {}
	return parsed
GD

cat > "$DEST/autoload/event_bus.gd" <<'GD'
extends Node
## EventBus — señales globales (bus de eventos nativo). No escribas otro mediador.
signal player_died
signal quest_completed(quest_id: StringName)
signal scene_change_requested(scene_path: String)
GD

# Escena principal mínima (4.6: sin load_steps).
cat > "$DEST/scenes/main.tscn" <<'TSCN'
[gd_scene format=3]

[node name="Main" type="Node3D"]
TSCN

# README mínimo del proyecto generado.
cat > "$DEST/README.md" <<MD
# $NAME

Proyecto Godot 4.6 generado con la skill godot-4.6-rpg (target: $TARGET, renderer: $RM).
Cierra el lazo tras cada cambio: \`bash verify_loop.sh\` (ya incluido en este proyecto).
MD

cd "$DEST"
git init -q && git add -A && git commit -q -m "scaffold $NAME ($TARGET) via godot-4.6-rpg skill" || true

# Warm-up de imports (puebla .godot/) si godot está disponible.
if command -v "$GODOT" >/dev/null 2>&1; then
  "$GODOT" --headless --path . --import --quit-after 2 >/dev/null 2>&1 || true
  echo "Proyecto listo en '$DEST'. Imports poblados."
else
  echo "Proyecto listo en '$DEST'. (Godot no está en PATH: corre 'godot --headless --import --quit-after 2' antes de verificar.)"
fi
