class_name ItemData extends Resource
## Datos de DISENO/AUTORIA: editable en el Inspector, tipado con @export.
##
## NUNCA uses custom Resources para guardar el progreso del jugador: cargar un
## .tres que el jugador pudo editar puede ejecutar codigo embebido (RCE). Para
## eso, JSON plano (ver save_manager.gd). Esto es solo para datos que crea el
## disenador y que vienen con el juego.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 999) var max_stack: int = 99
@export var icon: Texture2D
@export var tags: Array[StringName] = []


## Guarda en disco (autoria). En runtime usa CACHE_MODE_IGNORE al recargar.
static func save_to(item: ItemData, path: String) -> Error:
	return ResourceSaver.save(item, path)


static func load_from(path: String) -> ItemData:
	# CACHE_MODE_IGNORE fuerza relectura desde disco (evita instancia cacheada).
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
