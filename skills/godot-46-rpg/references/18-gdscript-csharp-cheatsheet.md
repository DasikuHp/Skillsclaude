## 18. Cheat-sheet GDScript 2.0 y C# (vs Godot 3)

> **El error nº1 de una IA con Godot es escupir "Godot-3-ismos".** Un LLM entrenado con código de GitHub 2018-2022 genera con total confianza `export var`, `onready var`, `yield(...)`, `emit_signal(...)`, `connect("x", self, "y")`, `tool`, `.metodo()` para super. **Todo eso parsea distinto o ni parsea en GDScript 2.0 (Godot 4.6).** Y como la IA *no ve el editor*, no nota que el nodo nunca se conectó, que el `.tscn` quedó con referencias rotas, o que el shader compila negro. Esta sección es una **tabla de traducción G3→4.6 + bloques "MAL vs BIEN"** indexados por **mensaje de error literal**, porque un agente sin editor encuentra el fallo por su *texto*, no por el concepto.

Verificado contra **Godot 4.6** (release 2026-01-27, mantenimiento ~4.6.3). GDScript 2.0, C# .NET 8. Jolt es el physics 3D por defecto en proyectos NUEVOS. D3D12 por defecto en Windows nuevo. Renderers: Forward+ / Mobile / Compatibility (web = Compatibility, **sin C#**).

---

### Enfoque nativo recomendado

GDScript 2.0, tipado estático, señales como objetos, `await`, `@abstract`, source generators de C# y el CLI headless son **core de 4.6**. No requieren ningún addon. La skill debe ser **doc-only / cheat-sheet**, no un plugin.

#### Tabla maestra Godot 3 (MAL) → Godot 4.6 (BIEN)

| Concepto | Godot 3 (MAL en 4.6) | Godot 4.6 (BIEN) |
|---|---|---|
| Export | `export var hp = 100` | `@export var hp: int = 100` |
| Export rango | `export(int, 1, 100) var x` | `@export_range(1, 100, 1, "or_greater") var x: int = 50` |
| Onready | `onready var spr = $Sprite` | `@onready var spr: Sprite2D = $Sprite2D` |
| Tool | `tool` (1ª línea) | `@tool` (1ª línea, anotación) |
| Coroutine | `yield(get_tree(), "idle_frame")` | `await get_tree().process_frame` |
| Coroutine timer | `yield(get_tree().create_timer(2),"timeout")` | `await get_tree().create_timer(2.0).timeout` |
| Coroutine señal | `yield(obj, "done")` | `await obj.done` |
| Declarar señal | `signal hit(amount)` | `signal hit(amount: int)` (params tipados) |
| Emitir señal | `emit_signal("hit", 10)` | `hit.emit(10)` |
| Conectar | `obj.connect("hit", self, "_on_hit")` | `obj.hit.connect(_on_hit)` |
| Conectar con flags | `connect("hit", self, "_on", [], CONNECT_DEFERRED)` | `obj.hit.connect(_on_hit, CONNECT_DEFERRED)` |
| Array tipado | `var a = []` | `var a: Array[int] = []` |
| Dict tipado | `var d = {}` | `var d: Dictionary[String, int] = {}` (desde 4.4) |
| StringName literal | `"jump"` (String) | `&"jump"` |
| NodePath literal | `"../Player"` | `^"../Player"` |
| Static var/func | (no existía) | `static var counter: int = 0` / `static func f()` |
| Lambda | (no existía) | `var f := func(x): return x*2` → `f.call(2)` |
| super | `.method()` | `super.method()` para cualquier método (p.ej. `super._ready()`); `super()` SOLO chaina el constructor `_init` |
| Instanciar escena | `scene.instance()` | `scene.instantiate()` |
| Abstracta | (no existía / hack `push_error`) | `@abstract class_name Base` / `@abstract func f()` (desde 4.5) |
| RNG en rango | `randi() % n` | `randi_range(0, n-1)` (preferido) |
| Shader screen tex | `SCREEN_TEXTURE` | `uniform sampler2D t : hint_screen_texture` |
| Shader depth tex | `DEPTH_TEXTURE` | `uniform sampler2D t : hint_depth_texture` |

#### Señales: objeto de primera clase + corrutinas

En 4.6 una señal **es una propiedad**. `emit_signal("x")` y `Object.connect("x", Callable)` siguen existiendo, pero úsalos **solo si el nombre es dinámico** (string en runtime). Para todo lo demás: `senal.emit()` / `senal.connect(callable)`.

```gdscript
signal died(score: int)              # args tipados
func _ready() -> void:
    died.connect(_on_died)           # Callable, sin string ni self
    died.connect(func(s): print(s))  # lambda como Callable
    died.connect(_on_died.bind("extra"))  # bind para argumentos extra
    died.emit(100)                   # .emit, NO emit_signal
    await get_tree().create_timer(1.0).timeout  # await + propiedad-señal
```

**await devuelve el argumento de la señal** (clave en RPGs: turnos, cutscenes). Si la señal emite 1 arg, lo recibes directo; si emite varios, recibes un `Array`:

```gdscript
var result = await $AttackPopup.choice_made   # pausa sin bloquear el hilo
```

#### Tipos estáticos: arrays y dictionaries tipados

```gdscript
var loot: Array[ItemResource] = []
var stats: Dictionary[String, int] = { "atk": 10, "def": 5 }  # Dictionary[K,V] desde 4.4
```

#### preload vs load, static, @abstract, super

```gdscript
const Goblin := preload("res://enemies/goblin.tscn")   # PARSE-time, path constante
var enemy := load("res://enemies/%s.tscn" % id)        # RUNTIME, path dinámico

@abstract class_name Enemy extends CharacterBody3D
@abstract func take_damage(amount: int) -> void        # los hijos DEBEN override

func _ready() -> void:
    super()                  # llama al _ready del padre (NO ".ready()")
func take_damage(a: int) -> void:
    super.take_damage(a)     # super.metodo, NO ".take_damage"
```

#### C# (.NET 8): la clase DEBE ser `partial`

C# en Godot 4 usa **source generators**. Sin `partial`, no se generan `SignalName`/`PropertyName`/`MethodName` y la build falla.

```csharp
public partial class Player : CharacterBody3D   // partial OBLIGATORIO
{
    [Export] public int Hp { get; set; } = 100;
    [Signal] public delegate void DiedEventHandler(int score);  // sufijo EventHandler OBLIGATORIO

    public override void _Ready()
    {
        Camera3D cam = GetNode<Camera3D>("Camera3D");  // genérico tipado, sin cast manual
        Died += s => GD.Print("muerto ", s);            // event C# nativo
        EmitSignal(SignalName.Died, 42);                // StringName generado, NO string mágico
        GD.Print("ready");                              // GD.Print, NO Console.WriteLine
    }
}
```

- Colecciones que **cruzan a la API del motor** (exports, señales): `Godot.Collections.Array<T>` / `Godot.Collections.Dictionary`. `System.Collections.Generic.List<T>` **no se marshalea** a métodos del engine. Los `Packed*Array` mapean a arrays nativos (`int[]`, etc.).
- Usa `SignalName.X` / `MethodName.X` / `PropertyName.X` en hot-paths: un string literal asigna una `StringName` nueva en cada llamada.

---

### Pitfalls y mensajes de error literales

| Mensaje literal | Causa | Fix |
|---|---|---|
| `Expected end of statement after variable declaration, found "var"` | `export var` / `onready var` (sintaxis G3) | `@export var` / `@onready var` |
| `Function "yield()" not found in base self` | `yield(...)` de G3 | `await señal` |
| `Invalid type in function 'connect' ... expected to be a Callable but is "String"` | `connect("x", self, "y")` (firma G3 de 3 args) | `obj.x.connect(_on_x)` |
| `preload() requires a constant expression` | `preload(ruta_variable)` | usar `load(...)` para paths dinámicos |
| `Trying to assign an array of type "Array" to a variable of type "Array[String]"` | asignar array sin tipo a uno tipado | `var t: Array[String] = []; t.assign(untyped)` |
| `Expected closing "]" after array type` | **anidamiento de tipos** `Dictionary[String, Array[String]]` o `Array[Array[int]]` — NO soportado (GH-proposals 12224) | tipo externo sin parametrizar el interno (`Array[Array]`) o un `Resource` dedicado |
| `Trying to assign a dictionary of type 'Dictionary[K, Nil]' to ... 'Dictionary[K, int]'` | pasar dict tipado concreto donde se espera `Dictionary[K, Variant]` — Variant NO es supertipo (GH-105843) | no anotar el parámetro como `Dictionary[K, Variant]`; usar el mismo tipo concreto o `Dictionary` sin parametrizar |
| `Cannot instantiate abstract class "X"` | `X.new()` sobre clase `@abstract` | instanciar una subclase concreta (comportamiento deseado) |
| `Annotation "@tool" must be at the top of the script` | anotación bajo otra declaración | mover `@tool`/anotaciones al inicio |
| `Invalid call. Nonexistent function ... in base 'null instance'` (runtime) | usar `@onready var x` en `_init()` — aún es `null` | usar `x` solo desde `_ready()` en adelante |
| `Cannot convert argument from String to StringName` (AnimationPlayer, 4.6) | `current_animation`/`assigned_animation`/`autoplay` pasaron de **String→StringName** (GH-110767); `get_queue()` → `StringName[]` | GDScript: usar `&"idle"`. **NO afecta nombres de track.** |
| C#: `GD0001: Missing partial modifier on declaration of type 'X'` | falta `partial` | añadir `partial` |
| C#: `... does not contain a definition for 'SignalName'` | falta `partial` (no se generó) | añadir `partial` |
| C#: `GD0201: The name of the delegate must end with 'EventHandler'` | delegate de señal sin el sufijo requerido | `delegate void XEventHandler(...)` |
| C#: `GD0202: The parameter of the delegate signature of the signal is not supported` | tipo de parámetro de la señal no marshalable | usar un tipo soportado (primitivos, `Variant`, tipos del engine) |
| C#: `Can't emit non-existing signal "X"` (runtime) | falta sufijo `EventHandler` | renombrar el delegate (GH-82268) |
| C#: `CS0246: type or namespace '...' could not be found` | frecuentemente **cache de build corrupta**, no tu código | `dotnet clean`, borrar `.godot/mono/` y `.mono/`, reconstruir (GH-68411) |
| C#: error al compilar tras actualizar a 4.6 con `CurrentAnimation = "run"` | StringName breaking (GH-110767): C# NO es source-compatible | `anim.CurrentAnimation = (StringName)"run";` |
| Shader: `Use of reserved keyword` / `Expected valid type hint after ':'` | `SCREEN_TEXTURE`/`DEPTH_TEXTURE` eliminados (PR #70967) | `uniform sampler2D t : hint_screen_texture, filter_linear_mipmap;` |
| Inspector muestra "Resource" genérico en `@export var a: Array[MiTipo]` | el tipo se cargó con `preload` en vez de `class_name` (GH-109574) | dar `class_name` al tipo custom |
| `Bug: Dictionary::operator[] used when there was no value` (al migrar 4.5→4.6) | acceso a clave inexistente en dict tipado (GH-115624) | `dict.get(key, default)` o `if key in dict` |

---

### Cómo no quedarte atascado

Una IA sin editor falla por **estado invisible del proyecto**, no solo por sintaxis. Protocolo de desatasque:

1. **Valida SIEMPRE por CLI antes de afirmar "funciona".** Un Godot-3-ismo salta como `Parse Error` aquí, gratis:
   ```bash
   godot --headless --check-only --script res://player.gd   # valida sintaxis sin abrir ventana
   godot --headless --import                                 # reimporta assets, regenera .uid (evita "resource not found")
   godot --headless --export-release "Linux" build/game.x86_64
   godot --headless --quit-after 3 --verbose                 # smoke test: arranca, loguea y sale
   ```
2. **`.tscn` / `uid://` — la mina de editar a mano.** Desde 4.4 los recursos se referencian por `uid://...` + ficheros `.uid` sidecar; en 4.6 los `.tscn` **ya no escriben `load_steps`** en la cabecera y se guardan IDs de nodo únicos. **No inventes un `uid://`** (no hay forma determinística de derivarlo de la ruta): lee el `.uid` existente o deja que el editor lo genere. Tras tocar archivos a mano, instruye al humano: **`Project > Tools > Upgrade Project Files`** (no hay flag CLI 100% equivalente para reescribir `.tscn`). Avisa que una escena guardada en 4.5 produce **diffs grandes** al re-guardarse en 4.6 — es esperado, no un bug.
3. **Las 3 acciones "solo-editor" que un agente debe delegar al humano:** (a) Upgrade Project Files; (b) asignar `class_name` al tipo custom para que `@export var a: Array[MiTipo]` ofrezca "New MiTipo"; (c) regenerar UIDs. La IA debe *instruir*, no inventar texto en el `.tscn`.
4. **Plataforma/render invisible.** Pregunta o asume el renderer. **Web = Compatibility, SIN C#** → si el proyecto apunta a web, el gameplay debe ser GDScript. Los shaders de screen/depth dan textura negra/vacía en Compatibility/web (GH-97728) — "compila" no implica "funciona"; advierte siempre.
5. **emit vs await.** `signal.emit()` devuelve `void`, **no es awaitable**. `await mi_senal` espera la *próxima* emisión. La API core no conoce las corrutinas: no puedes "await a todos los listeners" (GH-86862).
6. **Nunca inventes API.** Ante la duda `emit_signal`/`.emit()`, `String`/`StringName`, verifica contra `docs.godotengine.org/en/4.6/classes/`.

---

### Addon vs construirlo

| Necesidad | Recomendación | Por qué |
|---|---|---|
| Cheat-sheet / migración G3→4.6 | **Core, doc-only** | No hay addon fiable que convierta Godot-3-ismos en runtime. El conversor 3→4 es one-shot del editor. |
| Físicas 3D | **No instales nada.** Jolt está integrado en 4.6 | El addon `godot-jolt` es **redundante/obsoleto** en 4.6. **Ojo:** Jolt es default solo en proyectos NUEVOS; un proyecto **migrado** sigue en Godot Physics hasta cambiar `physics/3d/physics_engine` en Project Settings. Recomendar "Jolt ya está activo" sin verificar es FALSO. |
| Diálogos / cutscenes | **Addon: Dialogue Manager** (nathanhoad) | Editor de ramas, mantenido, MIT. Reinventarlo son semanas. |
| Inventario / stats / items | **Construir con `Resource` + `@export`** | `class_name Item extends Resource` es trivial en 4.6; los addons te acoplan a su UI. |
| Save/load | **Construir** con `ResourceSaver` + UIDs | En RPG quieres versionar tu schema tú mismo. |

Regla: **addon para lo que tiene UX/editor complejo (diálogos); build-it-yourself para data+lógica**, porque el `Resource` tipado de 4.6 hace que construirlo salga más barato que aprender el addon.

---

**Veredicto ponytail:** el mejor código aquí es el que no escribes. Antes de generar una línea de GDScript/C#, **valídala con `godot --headless --check-only`** — es el sustituto del botón Play para un agente ciego. Reusa nodos y `Resource` nativos antes que código custom, deja que el editor reescriba `.tscn`/`uid://` (nunca a mano), y trata esta sección como un **índice por mensaje de error**: el modo de fallo dominante de un LLM no es no saber el concepto, es regurgitar Godot 3 con confianza. La tabla MAL→BIEN y los errores literales son el antídoto.



> **Escalera ponytail:** meta (referencia de lenguaje) · **net propio:** no es un sistema: es escribir GDScript 2.0/C# idiomático, no Godot 3.
