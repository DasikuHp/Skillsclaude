# Valida que TODOS los .gd del proyecto parseen, con exit code FIABLE.
# Uso: godot --headless --path . --script res://ci/validate_all.gd
# extends SceneTree (NO EditorScript): no requiere --editor y es ligero en headless.
extends SceneTree

func _initialize() -> void:
	var errors: int = 0
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				# Saltar caché y addons (los addons traen sus propios scripts de editor).
				if entry != ".godot" and not entry.begins_with(".") and entry != "addons":
					stack.push_back(full)
			elif entry.ends_with(".gd"):
				# load() fuerza el parseo; si falla devuelve null y emite SCRIPT ERROR en stderr.
				var scr := load(full)
				if scr == null:
					push_error("PARSE FAIL: %s" % full)
					errors += 1
			entry = dir.get_next()
		dir.list_dir_end()
	if errors > 0:
		printerr("VALIDATION FAILED: %d script(s) con errores" % errors)
		quit(1)  # exit code propio y FIABLE: esquiva el bug de --check-only
	else:
		print("VALIDATION OK")
		quit(0)
