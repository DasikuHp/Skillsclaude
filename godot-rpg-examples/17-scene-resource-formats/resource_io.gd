extends RefCounted
## Genera y carga recursos por codigo en Godot 4.6 sin abrir el editor.
## ResourceSaver asigna y persiste el UID automaticamente; nunca lo inventes.

static func save_item(display_name: StringName, dmg: int, dir_path: String) -> Error:
	# Godot NO crea carpetas: crearla primero o save() devuelve ERR_CANT_OPEN.
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkerr := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkerr != OK:
			push_error("mkdir failed: %d" % mkerr)
			return mkerr

	var item := ItemData.new()
	item.display_name = display_name
	item.damage = dmg
	item.max_stack = 1

	var path := "%s/%s.tres" % [dir_path, String(display_name).to_snake_case()]
	var err := ResourceSaver.save(item, path)  # .tres = texto (VCS-friendly)
	if err != OK:
		push_error("save failed: %d" % err)
	return err


static func load_item(uid_or_path: String) -> ItemData:
	# load() acepta uid:// o res:// directamente; en export usa uid:// (robusto).
	if not ResourceLoader.exists(uid_or_path):
		push_error("resource not found: %s" % uid_or_path)
		return null
	return ResourceLoader.load(uid_or_path) as ItemData


static func resolve_uid(uid_text: String) -> String:
	# Resolver UID -> path actual (util en editor; poco fiable en export, godot#75617).
	var id := ResourceUID.text_to_id(uid_text)
	if ResourceUID.has_id(id):
		return ResourceUID.get_id_path(id)
	return ""


static func register_new_uid(res_path: String) -> String:
	# Crear y registrar un UID nuevo a mano (herramienta @tool / EditorScript).
	var new_id := ResourceUID.create_id()
	ResourceUID.add_id(new_id, res_path)
	return ResourceUID.id_to_text(new_id)  # -> "uid://..."
