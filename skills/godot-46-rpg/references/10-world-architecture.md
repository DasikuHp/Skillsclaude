## 10. Gestión de mundo / niveles y arquitectura

La gestión de mundo en un RPG 3D de Godot 4.6 NO requiere un framework propio: el stack nativo (`SceneTree`, `ResourceLoader` threaded, Autoload, groups/signals, `WorkerThreadPool`) cubre el 90% de lo que necesitas. El resto —streaming open-world por chunks— ya existe como addon mantenido. Esta sección parte de ese principio.

### Enfoque nativo recomendado

Cuatro pilares, ningún addon obligatorio:

1. **Cambio de escena completo — `SceneTree`.** `SceneTree.change_scene_to_packed(packed: PackedScene) -> Error` cuando ya tienes el `PackedScene` cargado (resultado de carga threaded), y `SceneTree.change_scene_to_file(path: String) -> Error` como atajo síncrono que carga el `.tscn` y bloquea. Accedes vía `get_tree()` desde cualquier `Node`, o `Engine.get_main_loop() as SceneTree`. **Gotcha verificado en docs**: ambos liberan la escena saliente de forma diferida (al final del frame), así que justo tras la llamada `get_tree().current_scene` puede ser `null`; no asumas cambio inmediato ([class_scenetree.change_scene_to_packed](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-change-scene-to-packed); ver tb. [docs issue #8868](https://github.com/godotengine/godot-docs/issues/8868)).

2. **Carga en background — `ResourceLoader` threaded.** Patrón canónico de los docs ([background_loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)):
   - `ResourceLoader.load_threaded_request(path, type_hint := "", use_sub_threads := false, cache_mode := CACHE_MODE_REUSE) -> Error`
   - `ResourceLoader.load_threaded_get_status(path, progress: Array = []) -> ThreadLoadStatus` — `progress` es array de salida; tras la llamada `progress[0]` ∈ 0.0–1.0. Estados: `THREAD_LOAD_INVALID_RESOURCE`, `THREAD_LOAD_IN_PROGRESS`, `THREAD_LOAD_FAILED`, `THREAD_LOAD_LOADED`.
   - `ResourceLoader.load_threaded_get(path) -> Resource` — recupera el recurso ya cargado; **bloquea** si lo llamas antes de `LOADED`.

   Flujo: `request` → sondear `get_status` en `_process()` actualizando la progress bar → al llegar a `LOADED`, `get` + `change_scene_to_packed` ([class_resourceloader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html)).

3. **Carga aditiva — `PackedScene` + `add_child()`.** No hay método especial: `packed.instantiate()` y `add_child()` (o `add_sibling()`). No reemplaza el árbol; las escenas coexisten y procesan en paralelo. Es la base del streaming open-world por tiles ([nodes_and_scene_instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html)).

4. **Autoload (singletons) + groups/signals.** Un autoload `SceneManager` enfocado SOLO en transiciones/loading screen/fade, configurado en Project Settings → Autoload, persiste across scene changes ([singletons_autoload](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)). Para desacoplar sistemas: `add_to_group()`, `get_nodes_in_group()`, `call_group()` y el patrón **"Call Down, Signal Up"** —llamadas hacia abajo, signals hacia arriba; conecta el padre común ([KidsCanCode](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/index.html), [GDQuest signals](https://www.gdquest.com/tutorial/godot/best-practices/signals/)).

Para trabajo CPU custom (generación procedural, baking de chunks, pathfinding batch) usa `WorkerThreadPool.add_task(action: Callable, high_priority := false, description := "") -> int` y **obligatoriamente** `wait_for_task_completion(task_id)` en algún momento para liberar recursos ([class_workerthreadpool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)). Para *cargar escenas*, prefiere `ResourceLoader` threaded (gestiona el threading por ti).

### GDScript

```gdscript
# scene_manager.gd — Autoload "SceneManager". Transición con fade + carga threaded.
extends Node

signal load_progress(value: float)   # 0.0..1.0 para la progress bar
signal load_finished

const FADE_TIME := 0.4

@export var fade_color: Color = Color.BLACK

var _target_path: String = ""
var _progress: Array = []             # array de salida para load_threaded_get_status
var _fade_rect: ColorRect

func _ready() -> void:
    set_process(false)
    _build_fade_overlay()

func _build_fade_overlay() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 128                 # encima de todo
    add_child(layer)
    _fade_rect = ColorRect.new()
    _fade_rect.color = fade_color
    _fade_rect.color.a = 0.0
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(_fade_rect)

func change_scene(path: String) -> void:
    await _fade_to(1.0)               # pantalla negra
    _target_path = path
    var err := ResourceLoader.load_threaded_request(path)  # use_sub_threads = false por defecto
    if err != OK:
        push_error("No se pudo pedir la carga de %s (err %d)" % [path, err])
        await _fade_to(0.0)
        return
    set_process(true)

func _process(_delta: float) -> void:
    if _target_path == "":
        return
    var status := ResourceLoader.load_threaded_get_status(_target_path, _progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            var p: float = _progress[0] if not _progress.is_empty() else 0.0
            load_progress.emit(p)
        ResourceLoader.THREAD_LOAD_LOADED:
            var packed: PackedScene = ResourceLoader.load_threaded_get(_target_path)
            _target_path = ""
            set_process(false)
            get_tree().change_scene_to_packed(packed)
            load_finished.emit()
            await _fade_to(0.0)       # fade-in sobre la escena nueva
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            push_error("Fallo cargando %s" % _target_path)
            _target_path = ""
            set_process(false)
            await _fade_to(0.0)

func _fade_to(target_alpha: float) -> void:
    var tween := create_tween()
    tween.tween_property(_fade_rect, "color:a", target_alpha, FADE_TIME)
    await tween.finished
```

Carga aditiva de un overlay/nivel (coexiste, no reemplaza el árbol):

```gdscript
var lvl: PackedScene = load("res://levels/dungeon.tscn")
var inst: Node = lvl.instantiate()
add_child(inst)   # streaming open-world: instancia/libera por proximidad del jugador
```

Trabajo paralelo CPU con `WorkerThreadPool` (cada task DEBE esperarse):

```gdscript
var tasks: Array[int] = []
for data in chunk_list:
    tasks.append(WorkerThreadPool.add_task(_bake_chunk.bind(data)))
for t in tasks:
    WorkerThreadPool.wait_for_task_completion(t)   # obligatorio: libera recursos
```

### C# (.NET 8)

```csharp
// SceneManager.cs — Autoload. Equivalente idiomático del flujo threaded + fade.
using Godot;

public partial class SceneManager : Node
{
    [Signal] public delegate void LoadProgressEventHandler(float value);
    [Signal] public delegate void LoadFinishedEventHandler();

    [Export] public Color FadeColor { get; set; } = Colors.Black;
    private const float FadeTime = 0.4f;

    private string _targetPath = "";
    private readonly Godot.Collections.Array _progress = new();
    private ColorRect _fadeRect = null!;

    public override void _Ready()
    {
        SetProcess(false);
        var layer = new CanvasLayer { Layer = 128 };
        AddChild(layer);
        _fadeRect = new ColorRect { Color = FadeColor with { A = 0f }, MouseFilter = Control.MouseFilterEnum.Ignore };
        _fadeRect.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(_fadeRect);
    }

    public async void ChangeScene(string path)
    {
        await FadeTo(1.0f);
        _targetPath = path;
        Error err = ResourceLoader.LoadThreadedRequest(path);  // useSubThreads: false (default) — ver Pitfalls
        if (err != Error.Ok)
        {
            GD.PushError($"No se pudo pedir la carga de {path}");
            await FadeTo(0.0f);
            return;
        }
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        if (_targetPath == "")
            return;

        var status = ResourceLoader.LoadThreadedGetStatus(_targetPath, _progress);
        switch (status)
        {
            case ResourceLoader.ThreadLoadStatus.InProgress:
                float p = _progress.Count > 0 ? _progress[0].AsSingle() : 0f;
                EmitSignal(SignalName.LoadProgress, p);
                break;
            case ResourceLoader.ThreadLoadStatus.Loaded:
                var packed = (PackedScene)ResourceLoader.LoadThreadedGet(_targetPath);
                _targetPath = "";
                SetProcess(false);
                GetTree().ChangeSceneToPacked(packed);
                EmitSignal(SignalName.LoadFinished);
                FadeIn();
                break;
            case ResourceLoader.ThreadLoadStatus.Failed:
            case ResourceLoader.ThreadLoadStatus.InvalidResource:
                GD.PushError($"Fallo cargando {_targetPath}");
                _targetPath = "";
                SetProcess(false);
                FadeIn();
                break;
        }
    }

    private async void FadeIn() => await FadeTo(0.0f);

    private async System.Threading.Tasks.Task FadeTo(float targetAlpha)
    {
        Tween tween = CreateTween();
        // Track name como StringName: en 4.6 los nombres de track son StringName.
        tween.TweenProperty(_fadeRect, "color:a", targetAlpha, FadeTime);
        await ToSignal(tween, Tween.SignalName.Finished);
    }
}
```

**Gotchas C# verificados.** (1) `CallDeferred` marshala cada Variant; pasar tipos que no convierten limpio (clases custom, `Task`, genéricos) hace que **retorne sin ejecutar y sin excepción** —usa `Callable.From(() => ...)` con closure ([bugnet.io](https://bugnet.io/blog/fix-godot-csharp-call-deferred-not-running-on-main-thread)). (2) `useSubThreads: true` + `LoadThreadedGet` puede **deadlock** con C# según jerarquía de nodos: déjalo en `false` ([#103674](https://github.com/godotengine/godot/issues/103674)). (3) NativeAOT: `LoadThreadedGet` puede colgar indefinidamente ([#87752](https://github.com/godotengine/godot/issues/87752)). (4) **C# no exporta a web en 4.6** —si tu RPG necesita navegador, GDScript + Compatibility es obligatorio. (5) **Recompila C# al pasar 4.5→4.6**: los nombres de track de `AnimationPlayer` pasaron de `String` a `StringName`; sin recompilar hay roturas silenciosas.

### Nodos/clases 4.6

- `SceneTree`: `change_scene_to_packed(PackedScene)`, `change_scene_to_file(String)`, `current_scene`, `get_nodes_in_group()`, `call_group()`.
- `ResourceLoader`: `load_threaded_request()`, `load_threaded_get_status()`, `load_threaded_get()`; enum `ThreadLoadStatus`.
- `PackedScene`: `instantiate() -> Node`.
- `Node`: `add_to_group()`, `remove_from_group()`, `add_child()`, `add_sibling()`.
- `WorkerThreadPool` (singleton): `add_task(Callable, bool, String) -> int`, `wait_for_task_completion(int)`, `add_group_task()`, `wait_for_group_task_completion()`.
- `CanvasLayer` + `ColorRect` + `Tween` para el fade overlay (patrón unánime en tutoriales).
- Autoload: cualquier `Node` registrado en Project Settings → Autoload.

### Pitfalls

- **Liberación diferida en cambio de escena.** Tras `change_scene_to_*`, la escena saliente se libera al final del frame y `current_scene` puede ser `null` ese frame. No accedas a `get_tree()` desde el nodo saliente asumiendo que sigue en el árbol.
- **Crash con múltiples escenas complejas.** `load_threaded_request()` crashea el engine al pedir varias escenas complicadas, reproducible en 4.6.dev1 ([#111202](https://github.com/godotengine/godot/issues/111202)). Verifica en tu patch (~4.6.3) y evita encadenar muchas requests pesadas simultáneas.
- **`progress[0]` puede quedarse en 0.** Issue histórico ([#56882](https://github.com/godotengine/godot/issues/56882)); con recursos pequeños puede saltar de 0 directo a `LOADED`. No asumas granularidad fina. Relacionado: el status a veces devuelve `INVALID_RESOURCE` espurio ([#95470](https://github.com/godotengine/godot/issues/95470)).
- **`use_sub_threads = true` cuelga editor/player.** ([#78734](https://github.com/godotengine/godot/issues/78734), [#103674](https://github.com/godotengine/godot/issues/103674)). Mantenlo en `false` por defecto.
- **Web export.** El background loading de `ResourceLoader` no funciona bien en builds Web ([#109914](https://github.com/godotengine/godot/issues/109914)), y C# no exporta a web. RPG en navegador → GDScript + Compatibility, y prueba el loading screen en el target real.
- **Autoload sobre-usado.** Anti-patrón documentado: UI, player, enemigos y save system todos colgando del mismo global. Mantén `SceneManager` enfocado SOLO en transiciones.
- **`change_scene_to_file` bloquea.** Carga síncrona; congela un frame en escenas grandes. Usa el flujo threaded + `change_scene_to_packed` para niveles pesados.
- **`WorkerThreadPool`: tasks sin esperar.** Toda task debe esperarse o se filtran recursos; `wait_for_task_completion` puede devolver `ERR_BUSY` si hay riesgo de deadlock por scheduling ([#84936](https://github.com/godotengine/godot/issues/84936)).

### Addon vs construirlo

**Constrúyelo tú (nativo, ~60 líneas):** cambio de escena con loading screen + fade es `SceneTree` + `ResourceLoader` threaded + un autoload `SceneManager`. Es el patrón de TODOS los tutoriales ([Coding Quests](https://codingquests.io/blog/godot-4-scene-transitions-fade), [Shaggy Dev](https://shaggydev.com/2022/06/13/godot-scene-transitions/), [GDQuest](https://www.gdquest.com/tutorial/godot/2d/scene-transition-rect/), [Let's Learn Godot RPG pt.18](https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-18-scene-transitions-day-night-cycle-4mnm)); cero dependencias, control total. Desacoplar sistemas → groups + signals nativos.

**Reutiliza un addon cuando el trabajo es no trivial:**
- **Streaming open-world por chunks** → [Godot-Open-World-Database](https://github.com/DigitallyTailored/Godot-Open-World-Database) (chunking + load/unload por proximidad de cámara, registra un autoload `Syncer`). El unload por proximidad es trabajo que no quieres reescribir.
- **Boilerplate de status-polling** → [AsyncScene](https://github.com/EiTaNBaRiBoA/AsyncScene) (replace root / replace child / additive con API simple).
- **Equipo C# que quiere `async/await` limpio** → [AsyncResourceLoaderForCS](https://github.com/ProFiLeR4100/AsyncResourceLoaderForCS), evita el polling y los gotchas de marshalling.
- **Fades/wipes listos** → [Transit](https://godotassetlibrary.com/asset/SpXqE2/transit-(godot-4)).
- **`ThreadPool`** del Asset Library → probablemente innecesario en 4.6; `WorkerThreadPool` nativo ya cubre casi todo.

Referencias de arquitectura: [godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg) (requiere Godot 4.6.2), [skelerealms](https://github.com/SlashScreen/skelerealms) (framework open-world tipo Bethesda), [architecture-organization-advice](https://github.com/abmarnie/godot-architecture-organization-advice), [project-structure-template](https://github.com/SlayHorizon/godot-project-structure-template). Confirma actividad reciente del repo antes de adoptar en producción.

**Veredicto ponytail:** NO construyas un "WorldManager" ni un sistema de threading propio. Reutiliza `SceneTree.change_scene_to_packed` + `ResourceLoader` threaded + un autoload `SceneManager` de ~60 líneas (`CanvasLayer`+`ColorRect`+`Tween` para el fade), groups/signals para desacoplar, y `WorkerThreadPool` solo para CPU custom. Para streaming open-world masivo NO rodes tu chunker: usa Godot-Open-World-Database. El mejor código de arquitectura es el que reutiliza nodos nativos.

# Temas avanzados: shaders, importación, errores, depuración y C# (anti-stuck)

Estas secciones existen para que un agente de IA (o un dev) **no se quede atascado**: cubren los puntos donde el motor falla en silencio o con mensajes crípticos. Cada una trae el enfoque nativo, código real, los **mensajes de error literales** con su fix, y una ruta de desatasque. Notas con fuentes en [`godot-rpg-research/`](./godot-rpg-research/).



> **Escalera ponytail:** rung 4 (SceneTree/autoload/grupos) · **net propio:** 3 autoloads de servicios reales; sin GameManager-dios.
