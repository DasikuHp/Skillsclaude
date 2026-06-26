## 8. Guardado / persistencia

Persistir el progreso de un RPG 3D en Godot 4.6 no requiere arquitectura propia: el engine trae tres mecanismos nativos, cada uno pensado para un tipo de dato distinto. La regla de oro de la comunidad (GDQuest, UhiyamaLab, Shaggy Dev) es **separar por tipo de dato**, no por comodidad.

| Dato | Mecanismo nativo | Por qué |
|------|------------------|---------|
| Settings (audio, vídeo, keybinds) | `ConfigFile` | INI tipado, cero parsing, defaults forward-compat |
| Progreso del jugador (HP, posición, quests, inventario) | `FileAccess` + `JSON` o `store_var` | Datos planos, portables, inspeccionables, **sin ejecución de código** |
| Datos de diseño/autoría (stats de ítems, tablas de enemigos) | Custom `Resource` + `ResourceSaver`/`ResourceLoader` | Editable en el Inspector, tipado, `@export` |

La frase que tienes que tatuarte: **`Resource` para datos que crea el diseñador; JSON/`store_var` para datos que escribe el jugador.** Cargar un `.tres` que el jugador pudo editar es un vector de ejecución de código (ver Pitfalls). Todo se escribe bajo `user://`; `res://` es read-only en builds exportados ([docs 4.6 runtime saving](https://docs.godotengine.org/en/4.6/tutorials/io/runtime_file_loading_and_saving.html)).

### Enfoque nativo recomendado

Clases 4.6 implicadas (sin cambios de API respecto a 4.5; enlaces a las páginas `class_*` versionadas en `/en/4.6/`):

- **`ConfigFile`** — settings. `set_value(section, key, value)`, `get_value(section, key, default)` (¡pasa siempre el 3.º argumento para no romper al añadir keys en updates!), `save("user://settings.cfg")`, `load(path)`. Variantes cifradas: `save_encrypted_pass` / `load_encrypted_pass` ([docs ConfigFile](https://docs.godotengine.org/en/4.6/classes/class_configfile.html)).
- **`FileAccess`** — E/S de bajo nivel. `FileAccess.open(path, FileAccess.WRITE|READ)` devuelve `null` si falla (chequea `FileAccess.get_open_error()`). `store_string()` / `get_as_text()` para texto; `store_var(value, full_objects=false)` / `get_var(allow_objects=false)` para binario seguro. `open_encrypted_with_pass(path, mode, pass)` para cifrado casual ([docs FileAccess](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)).
- **`JSON`** — serialización portable. Estático: `JSON.stringify(data, "\t")` (pretty-print) y `JSON.parse_string(text)` (devuelve `null` si error). Con instancia para diagnóstico: `var j := JSON.new(); j.parse(text)` + `j.get_error_message()` / `j.get_error_line()` ([docs JSON](https://docs.godotengine.org/en/4.6/classes/class_json.html)).
- **`ResourceSaver` / `ResourceLoader`** — solo para datos de autoría. `ResourceSaver.save(res, "user://x.tres")`; `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)` — usa `CACHE_MODE_IGNORE` o el cache (`CACHE_MODE_REUSE`, default) te devuelve la instancia vieja al recargar un slot ([docs ResourceSaver](https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html), [GDQuest](https://www.gdquest.com/library/save_game_godot4/)).

### GDScript

Sistema de save por slots con JSON plano y campo `version` para migración. Autoload (singleton). Patrón canónico de la comunidad ([Christine Coomans Part 20](https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-20-saving-loading-autosaving-4bl3)):

```gdscript
extends Node
## Autoload "SaveManager". Progreso del jugador como JSON plano (seguro).

signal game_saved(slot: int)
signal game_loaded(slot: int)

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves"

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func save_game(slot: int, player: Node3D, quests: Dictionary[StringName, int]) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data: Dictionary[String, Variant] = {
		"version": SAVE_VERSION,
		"player": {
			"hp": 80,
			# Vector3 no es JSON-nativo: serialízalo como array.
			"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"quests": quests,
	}
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("No se pudo abrir el save: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close() # explícito; también cierra al salir de scope (RefCounted)
	game_saved.emit(slot)
	return OK

func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		push_warning("Save corrupto en slot %d" % slot)
		return {}
	var data: Dictionary = parsed
	data = _migrate(data)
	game_loaded.emit(slot)
	return data

func _migrate(data: Dictionary) -> Dictionary:
	# Gotcha JSON: TODO número vuelve como float. Castea con int().
	var v := int(data.get("version", 1))
	if v < 2:
		# v1 no tenía "quests"; rellena el default.
		data["quests"] = {}
		data["version"] = 2
	return data
```

Para datos de **autoría** (no del jugador), un custom `Resource` tipado es lo idiomático:

```gdscript
class_name ItemData extends Resource
## Datos de diseño: editable en el Inspector, NO para saves del jugador.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_stack: int = 99
@export var tags: Array[StringName] = []
```

### C# (.NET 8)

Idiomático: `partial class : Node`, `[Export]`, `[Signal]` con delegados `EventHandler`. La comunidad usa `System.Text.Json` con `FileAccess` para la E/S, no el `JSON` de Godot ([Mouillard](https://medium.com/@romain.mouillard.fr/lightweight-saving-loading-system-in-godot-4-with-c-a-practical-guide-2cb6cbd2faa3), [Aceade](https://aceade.net/2025/01/12/parsing-arbitrary-json-in-godot-net/)). `System.Text.Json` mapea por nombre de propiedad (PascalCase por defecto); si renombras un campo del record o cambias el casing del JSON sin `[JsonPropertyName]`, el campo se deserializa a su valor por defecto silenciosamente:

```csharp
using Godot;
using System.Text.Json;

public partial class SaveManager : Node
{
    [Signal] public delegate void GameSavedEventHandler(int slot);
    [Signal] public delegate void GameLoadedEventHandler(int slot);

    private const int SaveVersion = 2;
    private const string SaveDir = "user://saves";

    // System.Text.Json NO serializa Vector3/Color/GodotObject:
    // guarda primitivas y reconstruye.
    private record SaveData(int Version, float Hp, float[] Pos);

    private static string SlotPath(int slot) => $"{SaveDir}/slot_{slot}.json";

    public Error SaveGame(int slot, Node3D player)
    {
        DirAccess.MakeDirRecursiveAbsolute(SaveDir);
        var pos = player.GlobalPosition;
        var data = new SaveData(SaveVersion, 80f, new[] { pos.X, pos.Y, pos.Z });
        string json = JsonSerializer.Serialize(data,
            new JsonSerializerOptions { WriteIndented = true });

        using var f = FileAccess.Open(SlotPath(slot), FileAccess.ModeFlags.Write);
        if (f is null)
            return FileAccess.GetOpenError();
        f.StoreString(json);
        EmitSignal(SignalName.GameSaved, slot);
        return Error.Ok;
    }

    // Deserialize<SaveData> devuelve SaveData? (null ante "null"/JSON vacío):
    // tipo de retorno anulable y guarda antes de usarlo (paridad con el GDScript).
    public SaveData? LoadGame(int slot)
    {
        string path = SlotPath(slot);
        if (!FileAccess.FileExists(path))
            return null;
        using var f = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (f is null)
            return null;
        SaveData? data;
        try { data = JsonSerializer.Deserialize<SaveData>(f.GetAsText()); }
        catch (JsonException) { GD.PushWarning($"Save corrupto en slot {slot}"); return null; }
        if (data is null) { GD.PushWarning($"Save corrupto en slot {slot}"); return null; }
        data = Migrate(data);
        EmitSignal(SignalName.GameLoaded, slot);
        return data;
    }

    private static SaveData Migrate(SaveData data) =>
        data.Version < SaveVersion
            ? data with { Version = SaveVersion, Pos = data.Pos ?? new float[] { 0f, 0f, 0f } }
            : data;
}
```

**Gotcha C# 4.6 (breaking 4.5→4.6):** propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Un `string` literal sigue compilando por conversión implícita; **leer** esas propiedades como `string` rompe a nivel de fuente. Recuerda además que las señales solo transportan tipos primitivos / builtin de Godot / `GodotObject`, lo cual condiciona cómo estructuras tus DTOs de save.

### Nodos/clases 4.6

- `ConfigFile` (Resource) — settings.
- `FileAccess` (RefCounted) — E/S, `store_var`/`get_var`, cifrado por password.
- `JSON` (RefCounted) — serialización portable.
- `ResourceSaver` / `ResourceLoader` (singletons) — solo datos de autoría; `CACHE_MODE_IGNORE` al recargar.
- `DirAccess` — crear `user://saves/` con `make_dir_recursive_absolute`.
- Un `Node` autoload como `SaveManager` con `signal` para notificar la UI.

### Pitfalls

- **Ejecución de código al cargar `.tres`/`.res`:** un Resource puede embeber un script que corre al cargar. Si cargas un save que el jugador editó, eso es RCE. Por eso el progreso va en JSON plano, no en Resources ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). Si **debes** cargar Resources como saves, usa el *Godot Safe Resource Loader* (drop-in que verifica que el `.tres` no contiene código).
- **`store_var`/`get_var` son seguros por defecto** (`full_objects=false` / `allow_objects=false`): binario sin serialización de objetos. Solo se vuelve peligroso si activas `full_objects=true` — ahí reintroduces el mismo riesgo que los Resources ([docs FileAccess](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)).
- **JSON convierte todo número a `float`:** un `int` guardado se relee como `1.0`. Castea con `int()`. Tipos Godot (`Vector3`, `Color`) no son JSON-nativos → serialízalos como arrays/strings.
- **Los `Dictionary[K,V]` tipados NO son compatibles con `JSON.parse_string`:** asignar el resultado a un `Dictionary[StringName, int]` lanza un error de asignación ([issue #97137](https://github.com/godotengine/godot/issues/97137)). Al recargar, trata el resultado como `Dictionary` sin tipar y reconstruye: las claves `StringName` vuelven como `String` y los enteros como `float`.
- **No guardes referencias a nodos ni `NodePath` vivos:** serializan estado roto al recargar la escena. Guarda IDs/coords y reconstruye.
- **Versionado de Resources: Godot NO lo tiene nativo** ([proposal #7567](https://github.com/godotengine/godot-proposals/discussions/7567)). Renombrar un `@export` o cambiar la jerarquía **pierde datos**. JSON + campo `"version"` + función `_migrate()` es lo robusto para saves de larga vida.
- **`ConfigFile.get_value` sin default rompe** al añadir keys en updates. Pasa siempre el 3.º argumento.
- **Cache de `ResourceLoader`:** `CACHE_MODE_REUSE` (default) devuelve datos viejos al recargar un slot; usa `CACHE_MODE_IGNORE`.
- **Cifrado no migra entre majors:** ficheros cifrados con Godot 3 no abren en Godot 4 ([issue #78815](https://github.com/godotengine/godot/issues/78815)). Y la password vive en el binario: frena edición casual, no a un atacante motivado.

### Addon vs construirlo

**Constrúyelo tú.** Para un RPG con versionado/migración serios, son ~80 líneas de `ConfigFile` + JSON, evita el riesgo de Resources y te da control total sobre la migración (que ningún addon resuelve). Usa addon solo en jam/prototipo o si ya tienes su arquitectura de nodos:

- **AdamKormos/SaveMadeEasy** — estilo PlayerPrefs de Unity, variables anidadas + cifrado ([repo](https://github.com/AdamKormos/SaveMadeEasy)).
- **TommyKooij/SaveSystem** — simple, Godot 4.5+ ([repo](https://github.com/TommyKooij/SaveSystem)).
- **KoBeWi/Metroidvania-System** — persistencia por IDs auto-generados, 4.5+ ([repo](https://github.com/KoBeWi/Metroidvania-System)).
- **MrRobinOfficial/Godot-Saveable (C#)** — Newtonsoft.Json, modos cifrado/comprimido/normal ([repo](https://github.com/MrRobinOfficial/Godot-Saveable)).
- Demos de referencia: [godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg), [skelerealms](https://github.com/SlashScreen/skelerealms).

**Veredicto ponytail:** no construyas un "SaveSystem" genérico ni un ORM de Resources con versionado propio. Reutiliza `ConfigFile` para settings y `FileAccess`+`JSON` (o `store_var` con `full_objects=false`) para el progreso, todo bajo `user://`, en un único `Node` autoload con un par de `signal`. Reserva `ResourceSaver`/`ResourceLoader` para datos de autoría que edita el diseñador, nunca para saves del jugador.



> **Escalera ponytail:** rung 4 (FileAccess/JSON) · **net propio:** serializas ids + datos planos a user://; sin ORM. # TECHO: JSON plano no versiona → UPGRADE: campo version + migración.
