## 12. Importación de assets

El error mental que atasca a casi toda IA: **Godot no edita tu asset de origen, lo importa**. Un `.glb`/`.blend`/`.png` se compila a un artefacto en `.godot/imported/` (`.scn`, `.ctex`) gobernado por un sidecar de texto INI `archivo.glb.import` (que contiene el `uid://`, el preset y los flags). En runtime cargas **el resultado importado** (un `PackedScene`), nunca el `.glb` "directamente". Tres niveles, y la confusión entre ellos es el bug #1:

1. **Source** (`.glb`) — lo entrega el artista.
2. **Import config** (`.glb.import`, importador `ResourceImporterScene`) — Import dock (global del archivo) + Advanced Import Settings (por nodo/material/mesh/animación).
3. **Imported resource** + instancia/escena heredada (lo que el juego carga y donde haces overrides sin tocar el import).

### Enfoque nativo recomendado

Todo el pipeline base es **nativo en 4.6**: glTF, `.glb`, `.blend`, FBX (importador interno **ufbx** desde 4.3, sin SDK propietario), AnimationLibrary, retargeting humanoide (`SkeletonProfileHumanoid` + `BoneMap` + `RetargetModifier3D`). **No necesitas addons** para un RPG de un personaje/prop.

Decisiones canónicas:

- **Formato: `.glb`** (binario, autocontenido). Reproducible, no necesita Blender en cada máquina ni en CI. Reserva `.blend` directo solo para iteración local en solitario; FBX solo para mocap heredado.
- **`.blend` directo** llama a Blender por debajo (`EditorSceneFormatImporterBlend`). Requiere **DOS** settings distintos: activar en *Project Settings → Filesystem → Import → Blender → Enabled*, **y** la ruta en *Editor Settings → Filesystem → Import → Blender → Blender Path* (clave `filesystem/import/blender/blender_path`). Desde el PR #85448 (mergeado en 2024, Godot 4.3+) la clave se renombró de `blender3_path` a `blender_path` y la ruta apunta al **ejecutable** de Blender (p.ej. `/usr/bin/blender` en Linux, `C:/Program Files/Blender Foundation/Blender 4.x/blender.exe` en Windows), **no a la carpeta**. Necesitas Blender 3.0+ (recomendado 4.x; versiones <3.3 tienen problemas conocidos de exportación).
- **Materiales: extráelos a archivos.** Los materiales del `.glb` son **Built-In** por defecto (embebidos, regenerados en cada reimport). Para editarlos persistente: Advanced Import Settings → selecciona el material → *Materials → Storage = Files (.material/.tres)* y/o *Keep On Reimport*. Para variantes en runtime usa `set_surface_override_material()`, no mutes el importado.
- **Texturas:** *VRAM Compressed* + *Mipmaps ON* para 3D; *Lossless* para UI/pixel-art 2D. **Color espacial:** albedo = sRGB; normal/roughness/metallic/AO = **linear (Non-Color)**. La opción *Normal Map* del importador solo surte efecto con VRAM Compressed.
- **Animaciones:** una escena base con malla+`Skeleton3D` (*Import As: Scene*); cada set de clips *Import As: Animation Library*, que se añaden a un único `AnimationPlayer` (`add_animation_library("locomotion", lib)`). Retarget Mixamo/mocap → tu rig vía `BoneMap` + `SkeletonProfileHumanoid` (auto-mapping si los huesos llevan nombres ingleses estándar), aplicado en runtime por `RetargetModifier3D`.
- **VCS:** commitea fuentes + `*.import` + `.tres`/`.material` extraídos; ignora `.godot/` entero.

### GDScript

```gdscript
extends Node3D

# Ruta conocida en compile-time: preload valida en editor y es más rápido.
# Cargas la ESCENA importada (PackedScene), nunca el .glb "crudo".
const EnemyScene: PackedScene = preload("res://assets/enemies/goblin.glb")

func spawn_static() -> Node3D:
	var enemy := EnemyScene.instantiate() as Node3D  # 4.x: instantiate(), NO instance()
	add_child(enemy)
	return enemy

# Ruta dinámica en runtime.
func spawn(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar PackedScene: %s" % path)
		return null
	var inst := packed.instantiate() as Node3D
	add_child(inst)
	return inst

# Override de material en runtime SIN tocar el import (material embebido = read-only).
func tint_enemy(inst: Node3D) -> void:
	var mesh := inst.get_node("Skeleton3D/Body") as MeshInstance3D
	var mat := preload("res://assets/materials/goblin_red.tres") as StandardMaterial3D
	mesh.set_surface_override_material(0, mat)

# Reproducir un clip de una AnimationLibrary. En 4.6 los nombres de animación del
# AnimationPlayer son StringName (GH-110767): usa literales &"..." para evitar
# fricción con tipado estricto / comparaciones.
func play_run(anim: AnimationPlayer) -> void:
	if anim.current_animation != &"locomotion/Run":
		anim.play(&"locomotion/Run")
```

Carga asíncrona para mundos grandes (evita stutter):

```gdscript
func request_async(path: String) -> void:
	ResourceLoader.load_threaded_request(path)

func poll_async(path: String) -> void:
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			add_child(packed.instantiate())
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Carga asíncrona falló: %s" % path)
```

Importar un `.glb` arbitrario en runtime (mods / user content) — `ResourceImporterScene` es editor-only, pero `GLTFDocument` funciona en exports:

```gdscript
func load_external_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("Couldn't load glTF scene: %d" % err)
		return null
	# Si cargas desde buffer (append_from_buffer) debes setear state.base_path
	# para que se resuelvan las texturas externas.
	return doc.generate_scene(state)
```

### C# (.NET 8)

```csharp
using Godot;

public partial class Spawner : Node3D
{
    // Ruta conocida: GD.Load directo.
    private readonly PackedScene _enemyScene =
        GD.Load<PackedScene>("res://assets/enemies/goblin.glb");

    public Node3D SpawnStatic()
    {
        var enemy = _enemyScene.Instantiate<Node3D>();
        AddChild(enemy);
        return enemy;
    }

    public Node3D? Spawn(string path)
    {
        var packed = ResourceLoader.Load<PackedScene>(path);
        if (packed == null)
        {
            GD.PushError($"No se pudo cargar PackedScene: {path}");
            return null;
        }
        var inst = packed.Instantiate<Node3D>();
        AddChild(inst);
        return inst;
    }

    // 4.6: current_animation/autoplay/etc. son StringName (GH-110767).
    // En C# eso cambia firmas: usa StringName, no string.
    public void PlayRun(AnimationPlayer anim)
    {
        StringName clip = "locomotion/Run";
        if (anim.CurrentAnimation != clip)
            anim.Play(clip);
    }
}
```

> **C# + web:** el render web es **Compatibility** y **web NO tiene C#** en 4.6. Si tu RPG exporta a web, mantén la carga/spawn de assets en GDScript.

### Notas de editor / Import dock (no es código)

- **Editar material persistente:** doble clic en el `.glb` → *Advanced Import Settings* → material → *Storage = Files* (extrae `.tres`/`.material`) → *Reimport*. Cambiar un campo NO reimporta solo: pulsa **Reimport**.
- **Colisión:** importar un mesh **no** crea collider (aunque Jolt sea el motor 3D por defecto). En *Advanced Import Settings* → nodo → *Create Collision* (Trimesh estático / Convex dinámico), o sufija objetos en Blender: `-col`, `-colonly`, `-convcol`, `-navmesh`. **Ojo en glTF/`.glb`:** los sufijos funcionan de forma fiable cuando están en el nombre del **NODO**; el sufijo `-colonly`/`-convcolonly` puesto sobre el nombre de la **MALLA** puede ser ignorado por el importador (issue #115869). Alternativa robusta: usa *Advanced Import Settings → Create Collision* por nodo en vez de depender del sufijo de malla.
- **Lightmaps:** activa *Generate Lightmap UV2* en el Import dock del mesh; no confíes en el segundo UV de Blender (issue #93884).
- **VCS `.gitignore`** (oficial de GitHub): ignora `.godot/`, **conserva** los `*.import`.

### Pitfalls y mensajes de error literales

| Síntoma / mensaje | Causa real | Fix canónico |
|---|---|---|
| Material editado **vuelve atrás** al reimportar | Material Storage = Built-In | *Advanced Import → Materials → Storage = Files* (+ Keep On Reimport), o escena heredada |
| Material del glb "read-only" por código | material embebido | `set_surface_override_material(0, mat)` con material propio |
| Modelo **negro** | (1) sin luz/environment — el 80% de los casos; (2) normales invertidas/ausentes; (3) normal map marcado sRGB | Añade `DirectionalLight3D` + `WorldEnvironment`; recalcula normales en Blender; normal map en **linear** |
| Caras **faltantes**/negras de un lado | normales invertidas / material single-sided | Blender: Normals → Recalculate Outside (Shift+N); o `cull_mode = Disabled` (issues #40329, #84358) |
| Modelo **gigante/diminuto** o **rotado 90°** | escala/ejes no aplicados (Blender Z-up vs Godot Y-up); FBX/ufbx mete empties ×100 | Blender: **`Ctrl+A → All Transforms`** antes de exportar; usa `.glb` no FBX (issue #90314) |
| `Blend file import is enabled... but no Blender path is configured` | falta ruta en **Editor** Settings | *Editor Settings → Filesystem → Import → Blender → Blender Path* (clave `blender_path`); apunta al **ejecutable** (p.ej. `/usr/bin/blender`, `...\blender.exe`), **no a la carpeta** |
| `.blend` no importa / X en FileSystem / CI cuelga | versión de Blender incompatible o ausente en PATH | versión 3.3+; en CI usa `.glb` exportado; primer pase `godot --headless --import --verbose` (issues #67275, #89767, #111265) |
| `glTF: Image index '0' couldn't be loaded with the name: Image_0. Skipping it.` | checkout limpio sin `*.import` (reimport con defaults) o `.godot/imported/` stale commiteado | commitea `*.import`, borra `.godot/`, reabre (issues #83200, #42235) |
| Escena que instancia un modelo **deja de cargar** tras re-export | `.glb` exportado **vacío** (Blender exportó con "Selected Objects" sin selección) | desmarca *Selected Objects*; valida tamaño del `.glb` antes de pisarlo (issues #68994, #82275) |
| Bandas/ruido en normal map a distancia | artefactos de mipmaps con VRAM compression | sube resolución fuente o usa Basis/uncompressed para esa normal (issue #57981) |
| Accesorios (espada, capa) **dejan de animarse** tras retarget | retargeting aplicado a personaje con accesorios animados | **desactiva** retargeting para ese personaje; actívalo solo en AnimationLibrary compartida |
| Animación deformada al retargetear | falta `BoneMap`/`SkeletonProfileHumanoid` o nombres de hueso no estándar | `BoneMap` + `SkeletonProfileHumanoid` consistentes, huesos en inglés |
| `Animation not found` / comparación de anim rara en 4.6 | props del player pasaron String→StringName (GH-110767) | usa literales `&"name"` (GDScript) / `StringName` (C#) |
| Reimport "colgado" en texturas 4K/8K | coste de VRAM compression (no es cuelgue) | paciencia 1ª vez, o redimensiona fuentes; si corrupto, borra `.godot/imported/` |

### Cómo no quedarte atascado (orden de diagnóstico)

1. **¿Negro?** → primero LUZ/environment, luego normales, luego sRGB del normal map.
2. **¿Gigante/diminuto/rotado?** → `Ctrl+A → All Transforms` en Blender, usa `.glb` no FBX.
3. **¿Material no editable / se revierte?** → Storage = Files + Keep, o escena heredada.
4. **¿Assets rotos tras `git clone`?** → faltan los `*.import` (o commiteaste `.godot/imported/` stale). Commitea `*.import`, ignora `.godot/`, borra caché, reimporta.
5. **¿`.blend` no importa?** → ruta de Blender en **Editor** Settings (`blender_path`, al **ejecutable** no a la carpeta) + versión 3.3+; si CI, pásate a `.glb`.
6. **¿Atraviesa el suelo?** → "Create Collision" en el import o sufijo `-col` (en glTF prefiere el sufijo en el **nodo**; `-colonly` sobre el nombre de la **malla** puede ignorarse, issue #115869).
7. **¿Accesorios no animan tras retarget?** → desactiva retargeting para ese personaje.
8. **¿Código de anims roto en 4.6?** → props del `AnimationPlayer` ahora `StringName` (`&"name"` / `StringName`).
9. **¿Mod/user-content en runtime?** → `GLTFDocument.append_from_file()` + `generate_scene()` (no `ResourceImporterScene`, que es editor-only).

### Addon vs construirlo

- **Pipeline base, retargeting, AnimationLibrary, colisión, FBX (ufbx):** todo nativo en 4.6 → **no construyas nada**.
- **Librerías de animación open-source listas para retarget:** `catprisbrey/Godot4-OpenAnimationLibraries` (reúsalo en vez de hacer mocap propio).
- **Importar niveles enteros con muchos prefabs posicionados:** *GLTF Level Importer* (burning-barb, itch.io) automatiza instanciado/materiales/colisión desde Blender — útil para blockouts, pero para producción de un RPG de un personaje/prop el pipeline nativo de Advanced Import Settings da más control sin dependencia externa.
- **CSG** (`CSGBox3D`...): solo para greybox/prototipado de niveles; recalcula geometría cada frame, sin LOD/lightmap decente. Greybox con CSG → modela en Blender → reimporta como `.glb`. No shippees CSG como geometría final.

**Veredicto ponytail:** el mejor código de importación es el que no escribes. Reúsa el `PackedScene` importado con `preload`/`load`, extrae materiales a `.tres` para editarlos en el editor en lugar de mutarlos por script, y deja que `RetargetModifier3D` + `SkeletonProfileHumanoid` + `BoneMap` hagan el retargeting nativo en vez de reescalar huesos a mano. La única línea de "código de import" legítima en runtime es `GLTFDocument` para mods/user-content; para todo lo demás, configura el Import dock y carga el resultado.



> **Escalera ponytail:** rung 4 (importadores nativos) · **net propio:** 0 código: configuras presets de import.
