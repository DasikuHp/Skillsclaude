## 13. Errores comunes y cómo desatascarse

Esta sección es el **catálogo de atascos reales** de un RPG 3D en Godot 4.6, con el **mensaje literal**, la causa según el ciclo de vida del nodo, y el **fix con APIs exactas de 4.6**. La idea central: no memorices mensajes, entiende el **modelo de ejecución y de referencias** y cada error se vuelve obvio.

### Enfoque nativo recomendado

El 70% de los bugs se disuelven con cuatro conceptos canónicos de 4.6 y herramientas integradas (sin addons):

| Concepto | Comportamiento documentado (4.6) |
|---|---|
| **Orden de inicialización** | `_init()` (constructor, árbol NO disponible) → `_enter_tree()` → (tras `NOTIFICATION_POST_ENTER_TREE`) asignación de `@onready var` → `_ready()`. Las `@onready` se resuelven justo ANTES de `_ready`, DESPUÉS de `_enter_tree` (dentro de `_enter_tree` aún NO están asignadas). `_ready` corre **bottom-up**: los hijos están listos ANTES que el padre. `$`/`get_node()` solo funciona dentro del árbol, nunca en `_init`. |
| **`@onready`** | Garantiza solo que **tus propios hijos** existen justo antes de `_ready`. NO garantiza hermanos, padres ni autoloads. No cambia el orden bottom-up. |
| **Hilo de física** | Toda mutación de cuerpos físicos (`velocity`, `move_and_slide`, `apply_force`) va en `_physics_process(delta)` (tick fijo, 60/s por defecto). `_process` es framerate variable. |
| **`Object` vs `RefCounted`** | `Node` deriva de `Object`: libéralo con `queue_free()`, no se autolibera. `RefCounted`/`Resource` usa conteo de referencias; los **ciclos NO se rompen solos**. |
| **`Callable` por identidad** | `connect`/`is_connected`/`disconnect` comparan por objeto+método (o misma instancia de lambda, o mismo `bind`). |

Herramientas nativas de desatasco, en este orden: **Remote scene tree** (¿el nodo existe y se llama así?) → **Debugger > Stack Frames** → **Debugger > Monitors** (Object Count, Orphan Node Count) → arrancar con `--verbose` (reporte de fugas al salir).

### GDScript

Los tres atascos diarios (Nil, señal doble, await colgado) y sus fixes idiomáticos:

```gdscript
extends Node3D

# --- 1. Nil / null instance: usa %UniqueName tipado para refs propias ---
# ROTO:  @onready var hud = $UI/HUD            # ruta frágil + sin tipo -> null silencioso
@onready var hud: Control = %HUD               # Scene Unique Name: sobrevive al re-parenting
@onready var player: CharacterBody3D = %Player

var target: Node3D                              # ref que puede morir (enemigo)

func _ready() -> void:
    # Referencias CRUZADAS (hermano/autoload/nodo dinámico): difiere, no las toques en _ready
    _wire_cross_refs.call_deferred()

func _wire_cross_refs() -> void:
    var boss := get_tree().get_first_node_in_group("boss")
    if is_instance_valid(boss):                 # guard canónico, siempre
        boss.died.connect(_on_boss_died)

func attack() -> void:
    # tras queue_free el objeto NO se vuelve null: valida antes de tocar
    if is_instance_valid(target) and not target.is_queued_for_deletion():
        target.take_damage(10)
    else:
        target = null

func _on_boss_died() -> void:
    pass
```

```gdscript
# --- 2. Señales: doble conexión y await que cuelga ---
func _connect_once(s: Signal, c: Callable) -> void:
    if not s.is_connected(c):                   # guard por identidad de Callable
        s.connect(c)
    # alternativa "una sola vez": s.connect(c, CONNECT_ONE_SHOT)

# await sobre señal que puede NO emitirse (el atasco más cruel: no hay error, cuelga)
func open_chest(anim: AnimationPlayer) -> void:
    anim.play(&"open")                          # &"..." = StringName literal (4.6)
    # carrera contra timeout: el primero que llegue desbloquea
    var timer := get_tree().create_timer(2.0)
    var done := [false]
    anim.animation_finished.connect(func(_n): done[0] = true, CONNECT_ONE_SHOT)
    await timer.timeout                          # garantiza salida aunque la señal nunca llegue
    if done[0]:
        pass # animación terminó normalmente
```

```gdscript
# --- 3. Física en _physics_process, sin doble delta ---
@export var speed := 6.0
@export var gravity := 18.0
var dir := Vector3.ZERO

func _physics_process(delta: float) -> void:
    velocity.x = dir.x * speed                   # SIN delta: move_and_slide lo aplica
    velocity.z = dir.z * speed
    velocity.y -= gravity * delta                # aceleración SÍ usa delta
    move_and_slide()
```

```gdscript
# --- 4. Mutar colección mientras se itera (bug silencioso: salta elementos) ---
# ROTO:  for e in enemies: if e.dead: enemies.erase(e)
func cull_dead(enemies: Array[Node3D]) -> Array[Node3D]:
    return enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
    # o recorrido inverso por índice:
    # for i in range(enemies.size() - 1, -1, -1):
    #     if enemies[i].dead: enemies.remove_at(i)
```

```gdscript
# --- 5. Tipado e inicialización + typed Dictionary 4.6 (trampa JSON) ---
var damage: int = 0                              # tipa E inicializa: evita 'Invalid operands Nil and int'
var loot: Dictionary[String, int] = {"gold": 10} # typed Dictionary (4.x, estricto en 4.6)

func load_config(txt: String) -> void:
    # ROTO: var d: Dictionary[String, int] = JSON.parse_string(txt)  # parse devuelve Dictionary[Variant,Variant]
    var raw: Variant = JSON.parse_string(txt)    # parsea SIN tipar, castea tú
    if raw is Dictionary:
        for k in raw:
            loot[String(k)] = int(raw[k])
    # En lecturas que pueden faltar, usa get() (evita el error de operator[] de 4.6, GH-115624):
    var g: int = loot.get("gold", 0)             # NO loot["gold"]
```

```gdscript
# --- 6. Ciclo RefCounted: rompe con weakref en UNA dirección (hijo -> padre) ---
class_name QuestStep extends RefCounted
var _quest_ref: WeakRef                          # débil, no fuerte
func set_quest(q: RefCounted) -> void:
    _quest_ref = weakref(q)
func get_quest() -> RefCounted:
    return _quest_ref.get_ref() if _quest_ref else null   # null si ya se liberó
```

### C# (.NET 8)

```csharp
using Godot;

public partial class PlayerController : Node3D
{
    private Node3D _target;
    private Node3D _emitter;

    public override void _Ready()
    {
        // Nil: GetNodeOrNull + guard. NUNCA GetNode en el constructor.
        var hud = GetNodeOrNull<Control>("%HUD");
        if (hud != null) hud.Visible = true;

        // Refs cruzadas: difiere hasta que todo el arbol exista.
        CallDeferred(nameof(WireCrossRefs));
    }

    private void WireCrossRefs()
    {
        _emitter = GetTree().GetFirstNodeInGroup("boss") as Node3D;
        // Guard idempotente: usa SignalName.* (validado), no el string crudo (cuelga si hay typo).
        if (_emitter != null && !_emitter.IsConnected(Node.SignalName.TreeExiting, Callable.From(OnEmitterGone)))
            _emitter.TreeExiting += OnEmitterGone;
    }

    public void Attack()
    {
        // queue_free no anula la ref: valida antes de usar.
        if (GodotObject.IsInstanceValid(_target))
            _target.Call("take_damage", 10);
    }

    private void OnEmitterGone() { }

    // C# NO desconecta solo todas las señales al liberar: hazlo aqui (evita NRE sobre nodo muerto).
    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_emitter) &&
            _emitter.IsConnected(Node.SignalName.TreeExiting, Callable.From(OnEmitterGone)))
            _emitter.TreeExiting -= OnEmitterGone;
    }

    // Fisica SIEMPRE en _PhysicsProcess: SINCRONO, muta los cuerpos aqui (nunca async void en un callback de motor).
    public override void _PhysicsProcess(double delta) { /* mover CharacterBody3D aqui */ }

    // await sobre senal -> en una corrutina async SEPARADA (invocada explicitamente), no en el callback de fisica.
    // 'async void' en _PhysicsProcess/_Process es antipatron: re-entrancia y excepciones no observables.
    private async void OpenChest(AnimationPlayer anim)
    {
        anim.Play("open");
        await ToSignal(anim, AnimationPlayer.SignalName.AnimationFinished);
    }
}
```

Nota C# 4.6 (StringName en AnimationPlayer, GH-110767): `current_animation`, `assigned_animation`, `autoplay`, el retorno de `GetQueue()` y el parámetro de la señal `current_animation_changed` pasaron de `String` a `StringName`. **Rompe binario y fuente en C#** (no en GDScript, que autoconvierte): actualiza tus comparaciones/asignaciones a `StringName`. Recuerda que **Web = Compatibility y sin C#**.

### Shader (.gdshader)

Breaking change 4.6 para shaders 3D custom (GLSL `SceneData`): `view_matrix` e `inv_view_matrix` pasaron de `mat4` a `mat3x4`. Si tu shader de agua/outline/niebla los usa, deja de tratarlos como 4x4 (rotación+traslación en 3x4) y transpón según convenga; de lo contrario la geometría sale deformada o no compila. Es el cambio que la guía oficial omitió al inicio (godot-docs#11744).

### Pitfalls y mensajes de error literales

- `Invalid get/set index 'X' (on base: 'Nil')` / `Cannot call method 'X' on a null value` (C#: `NullReferenceException`) → la ref es `null`. Causas por frecuencia: (a) ruta `@onready` mal escrita; (b) acceso a hermano/padre en `_ready` (bottom-up); (c) `get_node`/`$` antes de `add_child`; (d) `await` invalidó la ref.
- `Attempt to call function 'X' on a previously freed instance` → guardaste ref a un nodo `queue_free`'d. Guard: `is_instance_valid(x)` (+ `is_queued_for_deletion()` dentro del mismo frame).
- `Node not found: "<path>"` → typo, ruta absoluta `/root/...` fuera del árbol activo, o nodo aún no instanciado. Fix: `%UniqueName` o `get_node_or_null()` + guard.
- `Signal 'X' is already connected to given callable` → doble `connect` (reentrada, escena heredada con conexión del editor). Fix: `is_connected()` o `CONNECT_ONE_SHOT`. Lambdas inline: `is_connected(func(): ...)` SIEMPRE da `false` (otra instancia); guarda la lambda en variable.
- `Error calling from signal '<s>' to callable: ... Method expected N arguments, but called with M` → la firma del handler debe igualar args de la señal + args de `bind()` (los de `bind` van al final).
- `await ... does not return a coroutine` (warning) o **cuelgue silencioso sin error** → `await` sobre no-corutina, o sobre una señal que nunca se emite (emisor liberado, typo en nombre de señal, `emit` en rama muerta).
- `Identifier "X" not declared in the current scope` → typo/scope, o `class_name` recién creado no cacheado → **Project > Reload Current Project** (o borra `.godot/` y reabre).
- `Class 'X' hides a global script class` / `class_name hides an autoload singleton` → `class_name` duplicado, o script embebido huérfano dentro de un `.tscn` (abre el `.tscn` como texto, busca `[sub_resource type="GDScript"]`).
- `Invalid operands 'Nil' and 'int' in operator '+'` / `Cannot convert` / `Trying to assign value of type 'X'` → tipos sin inicializar o mezcla incompatible.
- `Invalid assignment of property or key with value of type 'Dictionary'` → typed `Dictionary[K,V]` alimentado con `JSON.parse_string` (devuelve `Dictionary[Variant,Variant]`) o clave de tipo erróneo.
- `Dictionary::operator[] used when there was no value for the given key` (regresión 4.6, GH-115624) → leer clave inexistente con `dict[key]` en contexto tipado. Fix: `dict.get(key, default)`.
- Al cerrar: `ERROR: N RID allocations leaked` / `WARNING: ObjectDB instances leaked at exit` → fugas: `queue_free`, `RenderingServer.free_rid()` en `_exit_tree`, `weakref` para ciclos RefCounted.

### Cómo no quedarte atascado (pasos de decisión)

```
NO COMPILA (rojo en el editor, no arranca)
  "Identifier not declared"        -> typo/scope, o class_name no cacheado -> Reload Project / borra .godot
  "class_name hides ..."           -> class_name duplicado o script embebido huerfano en .tscn
  "Cannot convert" / "Invalid operands" / "assign type" -> tipos; Array[T] / Dictionary[K,V] / Nil
  "Invalid assignment ... Dictionary" -> typed dict mal alimentado (JSON, clave erronea)
  shader 3D custom no compila      -> SceneData view_matrix/inv_view_matrix mat4 -> mat3x4: adapta/transpon
  APIs de Godot 3 (yield, .instance(), connect con strings) -> migrar a 4.x

CRASHEA / spam de errores en runtime
  "(on base: 'Nil')" / null instance / NRE -> @onready ruta (usa %UniqueName tipado) | hermano/padre en _ready (call_deferred) | get_node antes de add_child | ref liberada (is_instance_valid)
  "Node not found: <path>"         -> %UniqueName / get_node_or_null + guard
  "previously freed instance"      -> is_instance_valid + is_queued_for_deletion
  "already connected to Callable"  -> is_connected guard / CONNECT_ONE_SHOT
  "expected N arguments, called with M" -> firma handler = args senal + bind
  "operator[] ... no value"        -> dict.get(k, default)
  al cerrar: RID/ObjectDB leaked   -> queue_free / free_rid / weakref

NO PASA NADA (corre sin error)
  await colgado para siempre       -> typo en nombre de senal | emisor hizo queue_free | emit en rama muerta -> timeout / valida emisor / SignalName.*
  senal "conectada" no dispara     -> print(sig.get_connections()) ; firma de args
  fisica no mueve / input ignorado -> mutaste en _process (usa _physics_process) | _input vs _unhandled_input | collision_layer/mask
  lista se salta elementos         -> mutar durante iteracion -> filter / duplicate / loop inverso

VA LENTO / RAM sube
  jitter al mover                  -> mover cuerpos en _physics_process; sin doble delta en move_and_slide
  Orphan Node Count sube           -> Monitors + print_orphan_nodes(); instantiate/new sin add_child o remove_child sin queue_free
  "ObjectDB instances leaked"      -> ciclo RefCounted -> weakref()
```

### Addon vs construirlo

Casi todo es **construir, no addon**: los fixes son patrones de código + APIs base (`is_instance_valid`, `is_connected`, `weakref`, `print_orphan_nodes`, panel Monitors, `--verbose`). Un autoload propio `SignalBus`/`EventBus` de ~10 líneas con señales tipadas centraliza conexiones y elimina los dobles `connect` y las refs cruzadas frágiles. Para regresiones en CI sí vale un addon: **GUT** (GDScript) o **GdUnit4** (GDScript+C#), que además detecta orphan nodes por test. Para diálogos/quests con muchos `await`, construye una state machine propia (o Dialogic) en vez de encadenar `await` largos: son la fuente nº1 de cuelgues silenciosos.

**Veredicto ponytail:** El mejor código anti-atasco es el que no escribes: apóyate en nodos y herramientas nativas antes de inventar. `%UniqueName` tipado en vez de rutas `$A/B/C/D` frágiles, `is_instance_valid()` antes de tocar referencias, `is_connected()`/`CONNECT_ONE_SHOT` en vez de tu propio registro de conexiones, `_physics_process` en vez de interpolación casera, y el panel **Monitors + `print_orphan_nodes()`** en vez de un profiler de memoria propio. Y la regla que ahorra horas: **antes de tocar nada, mira el Remote scene tree** — el 90% de los `on base: 'Nil'` se ve ahí sin escribir una línea.



> **Escalera ponytail:** meta (no construyes nada) · **net propio:** catálogo de errores; la escalera no aplica, es desatasque.
