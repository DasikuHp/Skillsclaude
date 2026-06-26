<!-- NOTA: copia de respaldo / búsqueda full-text. La versión MANTENIDA y canónica de esta skill es SKILL.md + references/. -->
---
name: godot-4.6-rpg
description: >
  Construir un RPG 3D libre (open-source) en Godot 4.6 con la filosofía
  ponytail: el mejor código es el que no escribes. Cubre GDScript y C#,
  features nuevas de 4.6 (Jolt por defecto, IKModifier3D, diccionarios
  tipados, clases @abstract, SSR/LOD) y los sistemas de RPG (estados,
  inventario, diálogo, combate, guardado) resolviéndolos con nodos y
  recursos nativos antes que con arquitectura propia. Úsalo cuando el
  usuario diga "RPG en Godot", "Godot 4.6", "personaje 3D", "inventario",
  "sistema de guardado", "GDScript vs C#", "cámara en tercera persona", "AnimationTree", "IK", "combate", "stats", "diálogo", "quests", "IA enemiga", "NavigationAgent3D", "HUD", "menús", o invoque /godot-4.6-rpg.
  Complementa, no sustituye, a la documentación oficial: ante una duda de
  API concreta, consulta los docs de la versión 4.6.
---

Antes de escribir UNA línea de un sistema de RPG en Godot, baja la escalera
ponytail. El motor ya trae casi todo lo de un RPG; la mayoría del "código de
gameplay" es plomería que Godot resuelve con un nodo o un Resource.

## La escalera (aplícala a cada sistema antes de codear)

1. ¿Hace falta que exista? Un RPG no necesita un `GameManager` singleton el día 1.
2. ¿Lo da un **nodo** de Godot? `CharacterBody3D`, `NavigationAgent3D`, `AnimationTree`, `AudioStreamPlayer3D`, `GPUParticles3D`. No reescribas su lógica.
3. ¿Lo da un **Resource**? Items, stats, recetas, diálogos, loot tables = `Resource` con `@export`. No clases de datos a mano, no JSON parseado a mano.
4. ¿Lo dan **señales + grupos + autoloads**? Es el bus de eventos nativo. No escribas tu propio EventBus si una señal basta.
5. ¿Es una línea? `velocity = direction * speed; move_and_slide()` ya es tu locomoción. No envuelvas `move_and_slide` en un framework.
6. Solo entonces: escribe el mínimo que funciona, tipado.

El veredicto ponytail al revisar un sistema: `net: -<N> líneas posibles.` Si no hay nada que cortar y usa nodos nativos: `Limpio. A jugar.`

## Qué trae 4.6 que cambia tus decisiones

- **Jolt es el motor de física 3D por defecto** en proyectos nuevos (2-3× en escenas complejas). No instales plugins de física; no toques el `PhysicsServer` salvo necesidad real. Si migras un proyecto 4.5, actívalo en Project Settings → Physics → 3D → Physics Engine = Jolt.
- **`IKModifier3D`** integra IK en el núcleo: FABRIK (cadenas: colas, tentáculos, columna), CCD (aproximado y rápido para tiempo real), y two-bone IK (óptimo para brazos/piernas, p. ej. pies pegados al terreno). Antes esto era un plugin o math propio: ahora es un nodo hijo del `Skeleton3D`. Bórralo de tu TODO de "escribir IK".
- **SSR rehecho** (reflejos screen-space más estables, mejor roughness, más rápido) y **LOD** que preserva mejor la forma de mallas multi-parte. Calidad gratis: no hagas tu propio sistema de impostores para empezar.
- **Diccionarios tipados**: `Dictionary[String, ItemData]`. Inspector mejor y type-safety. Úsalos para inventarios/tablas en vez de `Dictionary` suelto.
- **Clases y métodos `@abstract`** (desde 4.5): define la base de tus estados/items como abstracta en vez de simular interfaces con `assert`.
- **GDScript más rápido** por optimizaciones de bytecode, sobre todo en **código tipado**. Regla 4.6: si te importa el rendimiento de GDScript, **tipa todo** (`var hp: int`, `func take(dmg: int) -> void`). El tipado no es estilo, es velocidad.
- **Editor**: Select y Transform desacoplados (modo Transform + modo Select-only); GridMap pinta/borra con interpolación Bresenham (líneas sólidas al arrastrar). Útil para construir mazmorras con GridMap.

## GDScript vs C#: elige una, no las mezcles por sistema

- **GDScript** por defecto: iteración instantánea, integración total con el editor, señales y `@export` sin fricción. En 4.6 tipado va sobrado para la lógica de un RPG. Es la opción ponytail (menos andamiaje).
- **C#** solo si ya lo justificas: simulación pesada en CPU (pathfinding masivo, ECS propio, miles de entidades), o reutilizar librerías .NET. Usa **.NET 8**; en desktop todos los runtimes; NativeAOT (`PublishAOT=true`, target ≥ net7) para arranque rápido. Android/iOS con NativeAOT siguen **experimentales** y web **no** soporta C#. Si tu RPG apunta a web, GDScript.
- No partas un mismo sistema entre los dos lenguajes por moda. El cruce GDScript↔C# tiene coste de marshalling; cruza por arquitectura, no por capricho.

# Los 10 sistemas de un RPG en profundidad

Las siguientes 10 secciones cubren cada sistema con el enfoque nativo de 4.6, código **GDScript y C# (.NET 8)** listo para compilar, nodos/clases exactos, pitfalls, decisión *addon vs construirlo* y veredicto ponytail. Se apoyan en investigación web de junio 2026 (docs oficiales 4.6, GitHub, foro de Godot, GDQuest, Asset Library, StackOverflow); cada una cita sus fuentes reales y las notas completas están en [`godot-rpg-research/`](./godot-rpg-research/). Ejemplos ejecutables por sistema en [`godot-rpg-examples/`](./godot-rpg-examples/).

## 1. Controlador de personaje + cámara 3ª persona

En Godot 4.6 un controlador de 3ª persona de RPG se construye **casi por completo con nodos nativos**: `CharacterBody3D` para la locomoción cinemática y `SpringArm3D` para una cámara que no atraviesa paredes. No hace falta arquitectura propia para la cámara; solo escribirás unas ~40 líneas de lógica de movimiento.

### Enfoque nativo recomendado

Jerarquía de escena canónica (confirmada por docs oficiales 4.6 y tutoriales de la comunidad):

```
Player (CharacterBody3D)
├── CollisionShape3D            # CapsuleShape3D
├── Visual (Node3D)             # modelo + AnimationPlayer / AnimationTree
└── CameraPivot (Node3D)        # recibe yaw/pitch del ratón
    └── SpringArm3D             # gestiona distancia y colisión
        └── Camera3D
```

La clave del diseño es **desacoplar "hacia dónde miro" de "cuánto se acerca la cámara"**: el `CameraPivot` (un simple `Node3D`) recibe la rotación del ratón, y la `SpringArm3D` solo gestiona la distancia/colisión hacia atrás. El `SpringArm3D` castea un rayo (o, si se le asigna un shape, una forma) a lo largo de su eje Z local y reposiciona a sus hijos en el punto de colisión, con un `margin` opcional ([SpringArm3D docs](https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html)).

**APIs nativas (verificadas en docs 4.6):**

- `CharacterBody3D.velocity: Vector3` — propiedad; `move_and_slide()` la lee y la actualiza. En 4.x `move_and_slide()` **no acepta argumento** de velocidad (a diferencia de Godot 3) ([CharacterBody3D docs](https://docs.godotengine.org/en/4.6/classes/class_characterbody3d.html)).
- `move_and_slide() -> bool`, `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()`.
- `get_gravity() -> Vector3` — lee la gravedad del área/ProjectSettings como vector; preferido sobre leer manualmente el escalar `physics/3d/default_gravity` ([CharacterBody2D/3D guide](https://docs.godotengine.org/en/4.6/tutorials/physics/using_character_body_2d.html)).
- `floor_snap_length: float` (default 0.1) — pega el cuerpo al suelo tras `move_and_slide()`; subir a ~0.3–1.0 m en terreno irregular o bajadas.
- `floor_max_angle: float` (default 0.785398 rad ≈ 45°), `floor_stop_on_slope: bool` (default `true`), `motion_mode` (`MOTION_MODE_GROUNDED` por defecto).
- `SpringArm3D.spring_length`, `margin`, `collision_mask`, `shape: Shape3D` (si se asigna hace shape-cast en lugar de raycast), y `add_excluded_object(rid: RID)` para excluir el propio collider del Player ([SpringArm3D docs](https://docs.godotengine.org/en/4.6/classes/class_springarm3d.html)).
- `Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone=-1.0) -> Vector2`, `InputEventMouseMotion.relative`, `Input.mouse_mode = MOUSE_MODE_CAPTURED`.

**Jolt por defecto:** en proyectos 4.6 nuevos Jolt es el motor 3D por defecto. `CharacterBody3D` + `move_and_slide()` es lógica de cuerpo cinemático en el árbol de escena y funciona igual; pero el step-up/down de escaleras **sigue sin ser automático** (ver Pitfalls).

### GDScript

GDScript 2.0 con tipado estático, `@export`, `@onready`, señales y `class_name`. Movimiento relativo a cámara, gravedad solo en el aire, salto, y mouse-look sobre el pivote:

```gdscript
class_name PlayerController
extends CharacterBody3D

signal jumped
signal landed

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export_range(0.0005, 0.01, 0.0001) var mouse_sens: float = 0.003
@export var pitch_min: float = -1.2  # rad, mirando abajo
@export var pitch_max: float = 0.4   # rad, mirando arriba

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var _pitch: float = 0.0
var _was_on_floor: bool = true

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    # Excluir el collider del propio Player para que el brazo no colapse sobre él.
    spring_arm.add_excluded_object(get_rid())
    # Shape-cast con esfera pequeña: mas suave que raycast, evita pop-in en bordes.
    var s := SphereShape3D.new()
    s.radius = 0.3
    spring_arm.shape = s

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var mm := event as InputEventMouseMotion
        camera_pivot.rotate_y(-mm.relative.x * mouse_sens)
        _pitch = clampf(_pitch - mm.relative.y * mouse_sens, pitch_min, pitch_max)
        camera_pivot.rotation.x = _pitch
    elif event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    # Gravedad SOLO en el aire (no acumular en suelo).
    if not is_on_floor():
        velocity += get_gravity() * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
        jumped.emit()

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    # Direccion relativa al yaw del pivote de camara (aplanada al plano XZ).
    var dir := (camera_pivot.global_basis * Vector3(input.x, 0.0, input.y))
    dir.y = 0.0
    dir = dir.normalized()

    if dir:
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
    else:
        # Resetear SOLO los ejes XZ que controlamos, nunca la velocidad entera.
        velocity.x = move_toward(velocity.x, 0.0, speed)
        velocity.z = move_toward(velocity.z, 0.0, speed)

    move_and_slide()

    var grounded := is_on_floor()
    if grounded and not _was_on_floor:
        landed.emit()
    _was_on_floor = grounded
```

Para configurar `floor_snap_length`/`floor_max_angle` desde el editor o `_ready()`:

```gdscript
func _configure_floor() -> void:
    floor_snap_length = 0.5                  # pega el cuerpo en bajadas/escalones pequeños
    floor_max_angle = deg_to_rad(46.0)       # rampas un poco por encima de 45 graus
    floor_stop_on_slope = true               # no resbalar parado en pendientes
```

### C# (.NET 8)

Idiomático: `partial class : CharacterBody3D`, `[Export]`, `[Signal]` con delegados, y `StringName` cacheados para las acciones de input.

```csharp
using Godot;

public partial class PlayerController : CharacterBody3D
{
    [Signal] public delegate void JumpedEventHandler();
    [Signal] public delegate void LandedEventHandler();

    [Export] public float Speed { get; set; } = 5.0f;
    [Export] public float JumpVelocity { get; set; } = 4.5f;
    [Export(PropertyHint.Range, "0.0005,0.01,0.0001")]
    public float MouseSens { get; set; } = 0.003f;
    [Export] public float PitchMin { get; set; } = -1.2f;
    [Export] public float PitchMax { get; set; } = 0.4f;

    // StringName cacheados: evita allocs por frame al consultar acciones.
    private static readonly StringName MoveLeft = "move_left";
    private static readonly StringName MoveRight = "move_right";
    private static readonly StringName MoveForward = "move_forward";
    private static readonly StringName MoveBack = "move_back";
    private static readonly StringName Jump = "jump";

    private Node3D _cameraPivot = null!;
    private SpringArm3D _springArm = null!;
    private float _pitch;
    private bool _wasOnFloor = true;

    public override void _Ready()
    {
        _cameraPivot = GetNode<Node3D>("CameraPivot");
        _springArm = GetNode<SpringArm3D>("CameraPivot/SpringArm3D");

        Input.MouseMode = Input.MouseModeEnum.Captured;
        _springArm.AddExcludedObject(GetRid());

        var s = new SphereShape3D { Radius = 0.3f };
        _springArm.Shape = s;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion mm
            && Input.MouseMode == Input.MouseModeEnum.Captured)
        {
            _cameraPivot.RotateY(-mm.Relative.X * MouseSens);
            _pitch = Mathf.Clamp(_pitch - mm.Relative.Y * MouseSens, PitchMin, PitchMax);

            // Velocity/rotation son struct por valor: copiar, mutar, reasignar.
            Vector3 rot = _cameraPivot.Rotation;
            rot.X = _pitch;
            _cameraPivot.Rotation = rot;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        // delta llega como double en C#: castear a float para operar con Vector3.
        float dt = (float)delta;
        Vector3 velocity = Velocity;

        if (!IsOnFloor())
            velocity += GetGravity() * dt;

        if (Input.IsActionJustPressed(Jump) && IsOnFloor())
        {
            velocity.Y = JumpVelocity;
            EmitSignal(SignalName.Jumped);
        }

        Vector2 input = Input.GetVector(MoveLeft, MoveRight, MoveForward, MoveBack);
        Vector3 dir = _cameraPivot.GlobalBasis * new Vector3(input.X, 0.0f, input.Y);
        dir.Y = 0.0f;
        dir = dir.Normalized();

        if (dir != Vector3.Zero)
        {
            velocity.X = dir.X * Speed;
            velocity.Z = dir.Z * Speed;
        }
        else
        {
            velocity.X = Mathf.MoveToward(velocity.X, 0.0f, Speed);
            velocity.Z = Mathf.MoveToward(velocity.Z, 0.0f, Speed);
        }

        Velocity = velocity;   // reasignar la propiedad antes de move_and_slide
        MoveAndSlide();

        bool grounded = IsOnFloor();
        if (grounded && !_wasOnFloor)
            EmitSignal(SignalName.Landed);
        _wasOnFloor = grounded;
    }
}
```

**Gotchas C#:**
- `Velocity` (y `Rotation`) son `struct` por valor: **no** se puede `Velocity.X = ...` directamente sobre la propiedad; copia a un local, mútalo y reasigna.
- `_PhysicsProcess(double delta)` recibe `double`; castea a `(float)delta` para multiplicar `Vector3`.
- **Breaking 4.6** (aplica a la sección de animación, no a este controlador): la API expuesta de `AnimationPlayer` pasó a usar `StringName` en vez de `String` (GH-110767). Tras actualizar, revisa el código C# que pasa literales `string` a APIs de animación: puede requerir `StringName` explícito al compilar. La recompilación del ensamblado C# es automática al hacer build con 4.6.

### Nodos/clases 4.6

| Nodo / clase | Rol |
|---|---|
| `CharacterBody3D` | Cuerpo cinemático; `velocity`, `move_and_slide()`, `is_on_floor()`, `floor_snap_length`, `floor_max_angle`, `get_gravity()`. |
| `CollisionShape3D` + `CapsuleShape3D` | Collider del jugador. |
| `Node3D` (CameraPivot) | Recibe yaw (`rotate_y`) y pitch (`rotation.x`) del ratón. |
| `SpringArm3D` | Cámara collision-aware; `spring_length`, `margin`, `shape`, `add_excluded_object()`. |
| `SphereShape3D` | Forma del shape-cast del brazo (más suave que raycast). |
| `Camera3D` | Cámara final, hija del brazo. |
| `Input` / `InputEventMouseMotion` | `get_vector()`, `MOUSE_MODE_CAPTURED`, `relative`. |

### Pitfalls

- **Gravedad acumulada en suelo**: nunca `velocity += get_gravity()*delta` incondicional; envuélvelo en `if not is_on_floor()`, si no `velocity.y` crece sin límite y `is_on_floor()` falla en bordes.
- **No resetear la velocidad entera**: `velocity = Vector3.ZERO` al inicio del frame descarta gravedad y momentum que calculó `move_and_slide()`. Resetea solo los ejes XZ que controlas.
- **`move_and_slide()` sin argumento**: en 4.x lee de la propiedad `velocity`; si nunca la asignas, el cuerpo no se mueve ([CharacterBody3D guide](https://docs.godotengine.org/en/4.6/tutorials/physics/using_character_body_2d.html)).
- **SpringArm colapsando**: sin `add_excluded_object(get_rid())` el brazo detecta el propio cuerpo del Player y la cámara se pega a él. Alternativa: poner al Player en una capa que la `collision_mask` del brazo no incluya.
- **`floor_snap_length` corto**: el personaje "despega" en cimas de pendientes y pierde contacto en bajadas/escalones pequeños (godot#71993). Subir a ~0.3–1.0 m; con 0 el snapping se desactiva.
- **Deslizar parado en pendientes**: si `floor_max_angle` es menor que el ángulo de la rampa, Godot la trata como pared y desliza. Asegura `floor_stop_on_slope=true` y un ángulo que cubra tus rampas ([Bugnet](https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot)).
- **Step-up de escaleras NO automático**: limitación abierta del motor (godot-proposals#2751); con Jolt por defecto en 4.6 tampoco hay step-up integrado en `move_and_slide`. Soluciones: shape-cast manual de step-up o un addon.
- **Acumulación de `event.relative`**: si la acumulación de input está desactivada pueden llegar varios `InputEventMouseMotion` por frame; suma (no asignes) deltas ([Yo Soy Freeman](https://yosoyfreeman.github.io/article/godot/tutorial/achieving-better-mouse-input-in-godot-4-the-perfect-camera-controller/)).
- **C# y el cambio `String`→`StringName` en `AnimationPlayer` (GH-110767)**: aplica a la sección de animación, no a este controlador; tras actualizar a 4.6 revisa los literales `string` que pasas a APIs de animación (puede requerir `StringName` explícito). La recompilación del ensamblado es automática al hacer build con 4.6.

### Addon vs construirlo

- **Rueda propio** el movimiento de `CharacterBody3D`: son ~40 líneas y en un RPG querrás control total de slopes, snap, estados y locomoción. Los nodos nativos cubren el 90%.
- **Usa Phantom Camera** ([ramokz](https://github.com/ramokz/phantom-camera)) si necesitas múltiples cámaras, transiciones cinemáticas o lock-on a objetivos (típico de RPG de acción) — estilo Cinemachine, ahorra mucho frente a gestionar SpringArm a mano.
- **Para solo la cámara** (sin lógica cinemática), `SpringArm3D` nativo + pivote es suficiente; no necesitas addon.
- Como **arranque/prototipo** para 4.6: *Real Controller* ([asset 4494](https://godotengine.org/asset-library/asset/4494)) o *Third Person Controller* ([asset 3934](https://godotengine.org/asset-library/asset/3934), soporta 4.4/4.5/4.6); el repo MIT de GDQuest ([gdquest-demos](https://github.com/gdquest-demos/godot-4-3d-third-person-controller)) es excelente referencia (se escribió para 4.x, los patrones son idénticos en 4.6 — verifica las propiedades de nombre de animación (`current_animation`/`assigned_animation`/`autoplay`) tras importar, por el cambio String→StringName de 4.6 (GH-110767)).

**Veredicto ponytail:** NO construyas tu propio sistema de cámara con raycasts ni una FSM de cámara — `SpringArm3D` + un `Node3D` pivote ya hacen colisión, margen y shape-cast nativamente; reutiliza Phantom Camera solo si el RPG necesita lock-on/cinemáticas. Lo único que escribes a mano es la locomoción de `CharacterBody3D` (~40 líneas), porque ahí sí quieres control total de slopes y estados.

## 2. Animación / AnimationTree / IK

La animación de personaje en un RPG 3D de Godot 4.6 se resuelve con una pila nativa de cuatro capas: banco de clips (`AnimationPlayer`), control y blending (`AnimationTree` con `AnimationNodeStateMachine` + `AnimationNodeBlendSpace2D`), y post-pose por hueso (`Skeleton3D` con la familia `SkeletonModifier3D` / `IKModifier3D`). No hace falta escribir un sistema de animación propio: todo lo que sigue es reutilización de nodos de primera clase. La verdad incómoda del dossier — que `TwoBoneIK3D` usaría propiedades planas tipo `target_node` — quedó **refutada al verificar la clase**: la API real es por índice (`set_target_node(index, path)`) sobre un `setting_count`, porque un mismo modificador puede resolver varias cadenas IK a la vez ([TwoBoneIK3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/TwoBoneIK3D.xml)).

### Enfoque nativo recomendado

**Datos — `AnimationPlayer`.** Banco de clips. En 4.6 (GH-110767) varias propiedades de NOMBRE DE ANIMACIÓN pasaron de `String` a `StringName`: `current_animation`, `assigned_animation`, `autoplay`, `get_queue()` (ahora `StringName[]`) y el parámetro de la señal `current_animation_changed`. La guía oficial lo clasifica como "neither binary nor source compatible": en C# un string literal pasado a métodos que toman `StringName` sigue compilando por conversión implícita, pero LEER esas propiedades como `string` rompe a nivel de fuente. El track del hueso raíz se marca como root motion vía la propiedad `root_motion_track` del `AnimationMixer` ([class_animationplayer 4.6](https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html), [migración a 4.6](https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html)).

**Control — `AnimationTree`** (hereda de `AnimationMixer` en 4.6, [AnimationTree.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationTree.xml)). `tree_root` apunta a un `AnimationNodeStateMachine` (o `AnimationNodeBlendTree`); `anim_player` (NodePath) al `AnimationPlayer`; `advance_expression_base_node` al nodo base para expresiones de transición. El root motion se lee por frame con métodos heredados de `AnimationMixer`: `get_root_motion_position() -> Vector3` (delta de posición, NO velocidad), `get_root_motion_rotation() -> Quaternion`, `get_root_motion_rotation_accumulator() -> Quaternion` y `get_root_motion_position_accumulator() -> Vector3` ([AnimationMixer.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationMixer.xml)).

**Máquina de estados — `AnimationNodeStateMachine` + `AnimationNodeStateMachinePlayback`.** El playback se obtiene con `tree.get("parameters/playback")` y se castea a `AnimationNodeStateMachinePlayback`. Firmas verificadas: `travel(to_node: StringName, reset_on_teleport := true, start_position := 0.0)`, `start(node: StringName, reset := true, start_position := 0.0)`, `stop()`, `get_current_node() -> StringName`, `get_travel_path() -> StringName[]`, `is_playing() -> bool`. `travel()` recorre el grafo de transiciones con A\* ([AnimationNodeStateMachinePlayback.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationNodeStateMachinePlayback.xml), [kidscancode recipe](https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html)).

**Locomoción — `AnimationNodeBlendSpace2D`.** Mapea un `Vector2` (p. ej. x = strafe, y = forward/back) a clips ubicados en puntos 2D que Godot triangula. Se controla con `tree.set("parameters/<Nodo>/blend_position", Vector2(x, y))`.

**Post-pose / IK — `Skeleton3D` + `SkeletonModifier3D` / `IKModifier3D`.** Los modificadores son hijos del `Skeleton3D` y corren **después** de evaluar el `AnimationTree`, en el orden del árbol de escena. `IKModifier3D` (hereda de `SkeletonModifier3D`) es la base de la suite IK; su única propiedad propia relevante es `mutable_bone_axes` (bool) — controla la mutabilidad de los ejes del hueso; verifica el default en el editor/clase de tu build de 4.6 (cuidado con el bug [#113047](https://github.com/godotengine/godot/issues/113047), errores infinitos por `mutable_bone_axis`) — y gestiona N cadenas vía `setting_count` / `set_setting_count(n)` / `clear_settings()` ([IKModifier3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/IKModifier3D.xml), [artículo oficial IK 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)). Los 7 solvers: `TwoBoneIK3D` y `SplineIK3D` (deterministas, predecibles — ideales para pies/brazos); `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` (iterativos, convergen — para cadenas largas como colas/columnas); más `ChainIK3D` e `IterateIK3D` (base de los iterativos — `FABRIK3D` hereda de `IterateIK3D`). Para mirar (cabeza/ojos): `LookAtModifier3D` (4.4), con `bone_name`/`bone`, `target_node`, `forward_axis`, `use_angle_limitation`, `origin_from` ([LookAtModifier3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/LookAtModifier3D.xml)). Para colgar armas/props a un hueso: `BoneAttachment3D` (`bone_name` / `bone_idx`), también hijo del `Skeleton3D`.

API real de `TwoBoneIK3D` (por índice, NO propiedades planas): `set_root_bone_name(i, name)`, `set_middle_bone_name(i, name)`, `set_end_bone_name(i, name)`, `set_target_node(i, NodePath)`, `set_pole_node(i, NodePath)`, `set_pole_direction(i, dir)`, más getters `get_target_node(i)`, etc. El número de cadenas se fija con `setting_count`. Hereda `active` de `SkeletonModifier3D` para togglear todo el modificador.

### GDScript

```gdscript
extends CharacterBody3D
## Locomoción RPG: BlendSpace2D + state machine + root motion + IK de pie.

@export var move_speed: float = 4.0
@export_node_path("AnimationTree") var tree_path: NodePath
@export var foot_ray_length: float = 0.6

@onready var tree: AnimationTree = get_node(tree_path)
@onready var skel: Skeleton3D = $Visual/Skeleton3D
@onready var sm: AnimationNodeStateMachinePlayback = tree["parameters/playback"]
@onready var foot_ik_l: TwoBoneIK3D = $Visual/Skeleton3D/FootIK_L
@onready var foot_target_l: Marker3D = $Visual/Skeleton3D/FootTarget_L
@onready var foot_ray_l: RayCast3D = $FootRay_L

# Cachear StringName: en 4.6 los parámetros/tracks son StringName y NO autoconvierten.
const ST_BLEND: StringName = &"parameters/Locomotion/blend_position"
const ST_ATTACK: StringName = &"attack"
const ST_IDLE: StringName = &"idle"

signal attack_started

func _ready() -> void:
	tree.active = true
	# Configurar una cadena IK (setting 0) por código si no se hizo en el editor.
	foot_ik_l.set_setting_count(1)
	foot_ik_l.set_root_bone_name(0, &"UpperLeg.L")
	foot_ik_l.set_middle_bone_name(0, &"LowerLeg.L")
	foot_ik_l.set_end_bone_name(0, &"Foot.L")
	foot_ik_l.set_target_node(0, foot_ik_l.get_path_to(foot_target_l))
	foot_ik_l.active = false

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"left", &"right", &"back", &"forward")
	tree.set(ST_BLEND, input)
	_apply_root_motion(delta)
	move_and_slide()
	_update_foot_ik()

func _apply_root_motion(delta: float) -> void:
	# Patrón canónico: extrae la posición local corrigiendo por el accumulator de
	# rotación, válido incluso con cross-fade (evita el bug incremental #93821/#95688).
	var rot_acc := tree.get_root_motion_rotation_accumulator()
	var pos: Vector3 = tree.get_root_motion_position()  # delta local, no velocidad
	var local := (rot_acc.inverse() * quaternion) * pos
	velocity = (transform.basis * local) / delta if delta > 0.0 else Vector3.ZERO

func _update_foot_ik() -> void:
	if foot_ray_l.is_colliding():
		foot_target_l.global_position = foot_ray_l.get_collision_point()
		foot_ik_l.active = true
	else:
		foot_ik_l.active = false

func attack() -> void:
	sm.travel(ST_ATTACK)   # A* sobre las transiciones del grafo
	attack_started.emit()

# Diccionario tipado 4.6 para mapear acción de input -> estado de animación.
var action_to_state: Dictionary[StringName, StringName] = {
	&"slash": &"attack",
	&"roll": &"dodge",
}

func play_action(action: StringName) -> void:
	if action_to_state.has(action):
		sm.travel(action_to_state[action])
```

### C# (.NET 8)

```csharp
using Godot;

public partial class PlayerLocomotion : CharacterBody3D
{
    [Export] public float MoveSpeed { get; set; } = 4.0f;
    [Export] public NodePath TreePath { get; set; }

    [Signal] public delegate void AttackStartedEventHandler();

    // En C# los string literales se convierten IMPLÍCITAMENTE a StringName (cast
    // asignante), por lo que esto compila. El motivo de cachear en `static readonly
    // StringName` es de RENDIMIENTO: evitar alocar un StringName nuevo por frame (p. ej.
    // en _PhysicsProcess). El issue #64171 (falta de autoconversión) aplica a GDScript,
    // no a C#. En 4.6 (GH-110767) las propiedades de NOMBRE de animación de
    // AnimationPlayer (current_animation, assigned_animation, autoplay, get_queue())
    // pasaron a StringName: leerlas como `string` rompe a nivel de fuente.
    private static readonly StringName BlendParam = "parameters/Locomotion/blend_position";
    private static readonly StringName AttackState = "attack";

    private AnimationTree _tree;
    private AnimationNodeStateMachinePlayback _sm;
    private TwoBoneIK3D _footIkL;
    private Marker3D _footTargetL;
    private RayCast3D _footRayL;

    public override void _Ready()
    {
        _tree = GetNode<AnimationTree>(TreePath);
        _tree.Active = true;
        _sm = (AnimationNodeStateMachinePlayback)_tree.Get("parameters/playback");

        _footIkL = GetNode<TwoBoneIK3D>("Visual/Skeleton3D/FootIK_L");
        _footTargetL = GetNode<Marker3D>("Visual/Skeleton3D/FootTarget_L");
        _footRayL = GetNode<RayCast3D>("FootRay_L");

        _footIkL.SetSettingCount(1);
        _footIkL.SetRootBoneName(0, "UpperLeg.L");
        _footIkL.SetMiddleBoneName(0, "LowerLeg.L");
        _footIkL.SetEndBoneName(0, "Foot.L");
        _footIkL.SetTargetNode(0, _footIkL.GetPathTo(_footTargetL));
        _footIkL.Active = false;
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 input = Input.GetVector("left", "right", "back", "forward");
        _tree.Set(BlendParam, input);
        ApplyRootMotion((float)delta);
        MoveAndSlide();
        UpdateFootIk();
    }

    private void ApplyRootMotion(float delta)
    {
        // Patrón canónico: corrige la posición local por el accumulator de rotación
        // (válido con cross-fade; evita el bug incremental #93821 / #95688).
        Quaternion rotAcc = _tree.GetRootMotionRotationAccumulator(); // struct por valor
        Vector3 pos = _tree.GetRootMotionPosition();                  // delta local
        Vector3 local = (rotAcc.Inverse() * Quaternion) * pos;
        Velocity = delta > 0f ? (Transform.Basis * local) / delta : Vector3.Zero;
    }

    private void UpdateFootIk()
    {
        if (_footRayL.IsColliding())
        {
            _footTargetL.GlobalPosition = _footRayL.GetCollisionPoint();
            _footIkL.Active = true;
        }
        else
        {
            _footIkL.Active = false;
        }
    }

    public void Attack()
    {
        _sm.Travel(AttackState);
        EmitSignal(SignalName.AttackStarted);
    }
}
```

### Nodos/clases 4.6

- `AnimationPlayer` — banco de clips; en 4.6 (GH-110767) las propiedades de nombre de animación (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`) son `StringName`.
- `AnimationTree` : `AnimationMixer` — `tree_root`, `anim_player`, `advance_expression_base_node`, `callback_mode_process`, `active`; root motion vía `root_motion_track` / `get_root_motion_*()`.
- `AnimationNodeStateMachine` / `AnimationNodeStateMachinePlayback` — `travel`, `start`, `get_current_node`, `get_travel_path`, `is_playing`.
- `AnimationNodeBlendSpace2D` — blending 2D triangulado; `parameters/<Nodo>/blend_position`.
- `Skeleton3D` — esqueleto; contenedor de modificadores.
- `IKModifier3D` : `SkeletonModifier3D` — base IK; `setting_count`, `mutable_bone_axes` (verifica su default en tu build; ojo con el bug [#113047](https://github.com/godotengine/godot/issues/113047)), `clear_settings()`, `reset()`.
- `TwoBoneIK3D` : `IKModifier3D` — determinista; API por índice (`set_root_bone_name`, `set_middle_bone_name`, `set_end_bone_name`, `set_target_node`, `set_pole_node`).
- `FABRIK3D` : `IterateIK3D` / `CCDIK3D` / `JacobianIK3D` — iterativos.
- `SplineIK3D`, `ChainIK3D`, `IterateIK3D` — cadenas.
- `LookAtModifier3D` : `SkeletonModifier3D` — `bone_name`, `target_node`, `forward_axis`, `use_angle_limitation`.
- `BoneAttachment3D` — anclar props/armas a un hueso.

### Pitfalls

- **`StringName` en nombres de animación de `AnimationPlayer` (4.6, GH-110767)**: `current_animation`, `assigned_animation`, `autoplay`, `get_queue()` (ahora `StringName[]`) y la señal `current_animation_changed` pasaron de `String` a `StringName` ("neither binary nor source compatible"); leerlas como `string` en C# rompe a nivel de fuente. Cachear `StringName` en C# es por RENDIMIENTO (evitar alocar por frame), no correctitud; el issue [#64171](https://github.com/godotengine/godot/issues/64171) es de GDScript ([migración a 4.6](https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html)).
- **API IK por índice, no plana**: `TwoBoneIK3D` NO tiene `target_node` directo; usa `set_target_node(index, path)` sobre `setting_count`. Configura las cadenas en el editor o con `set_setting_count()` antes de los setters ([TwoBoneIK3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/TwoBoneIK3D.xml)).
- **Root motion + rotación**: la acumulación incremental con fading rompe la locomoción ([#93821](https://github.com/godotengine/godot/issues/93821), [#95688](https://github.com/godotengine/godot/issues/95688)). Usar `get_root_motion_rotation_accumulator()` y aplicar rotación absoluta.
- **`get_root_motion_position()` es delta, no velocidad**: orientarlo por el `basis` y dividir por `delta` antes de `move_and_slide()`. Considera `root_motion_local`.
- **Orden de modificadores**: IK/LookAt corren tras el `AnimationTree` y en orden del árbol; un `LookAtModifier3D` antes de un `TwoBoneIK3D` puede ser sobrescrito. `active` togglea cada uno.
- **`travel()` a sub-estado anidado**: bug histórico al viajar directo a un estado dentro de un SubStateMachine ([#62576](https://github.com/godotengine/godot/issues/62576)); workaround: travel al sub-SM y luego al estado interno.
- **IK iterativos no deterministas**: FABRIK/CCD/Jacobian pueden temblar (jitter); preferir `TwoBoneIK3D` para extremidades de personaje ([foro IK 4.6](https://forum.godotengine.org/t/which-godot-4-6-ik-solver-is-best-for-player-pose-tracking-fabrik-vs-twobone-vs-ccd/129191)).
- **Retargeting Mixamo**: clips con rest pose T/A correcta + `SkeletonProfileHumanoid` + `BoneMap`; fuentes sin rest pose válida producen poses raras ([#89244](https://github.com/godotengine/godot/issues/89244)).

### Addon vs construirlo

- **IK**: NO usar addon. Es nativo y de primera clase en 4.6 (suite `IKModifier3D`). La escena de muestra [Inverse Kinematics Example](https://store.godotengine.org/asset/andicraft/inverse-kinematics-example/) sirve solo como referencia de setup, no como dependencia.
- **State machines de animación**: `AnimationNodeStateMachine` nativo basta para locomoción/combate. Para el **cerebro de IA** (separado de la animación) considerar [LimboAI](https://github.com/limbonaut/limboai) (behavior trees + HSM con editor y debugger) o XSM. Regla: animación = `AnimationTree` nativo; IA = LimboAI.
- **Retargeting Mixamo**: nativo (`BoneMap` + `SkeletonProfileHumanoid`) funciona; el plugin [RaidTheory/Godot-Mixamo-Animation-Retargeter](https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter) automatiza el bone map para flujos masivos de clips — innecesario para pocos.

**Veredicto ponytail:** No construyas un sistema de animación, un blend tree ni un solver IK propios, ni un wrapper de "propiedades planas" sobre `TwoBoneIK3D`. Reutiliza `AnimationTree` + `AnimationNodeStateMachine` + `AnimationNodeBlendSpace2D` para control y blending, root motion nativo (`get_root_motion_*` con el accumulator), y la suite `IKModifier3D` (TwoBoneIK3D determinista para pies/brazos, LookAtModifier3D para la cabeza, FABRIK3D/CCDIK3D para colas) como hijos del `Skeleton3D`. Para IA, delega en LimboAI en vez de mezclar gameplay con animación.

## 3. Combate y daño

El combate de un RPG 3D en Godot 4.6 se resuelve casi por completo con tres recursos que la engine ya te da: `Area3D` para la detección de golpes, un `Resource` propio para los datos del daño, y `Timer` para i-frames y ventanas de ataque. No necesitas un motor de combate; necesitas conectar señales y dejar que las capas de colisión hagan el filtrado.

### Enfoque nativo recomendado

El patrón canónico (confirmado en docs oficiales, GDQuest y el addon de cluttered-code) es **Hitbox/Hurtbox sobre `Area3D`**, NO sobre `body_entered` de cuerpos físicos. Esto desacopla la detección de golpes del movimiento físico y se comporta igual en Forward+, Mobile y Compatibility ([GDQuest](https://www.gdquest.com/library/hitbox_hurtbox_godot4/)).

Reparto de responsabilidades (terminología GDQuest):

- **Hitbox** = la parte que *inflige* daño (arma, puño, proyectil). `Area3D` + `CollisionShape3D` hijo.
- **Hurtbox** = la parte que *recibe* daño (cuerpo del personaje). También `Area3D` + `CollisionShape3D`.

**Deja que las capas de colisión hagan el chequeo de tipos.** Si configuras bien `collision_layer`/`collision_mask`, solo un lado emite la señal y te ahorras `is`/casts en runtime, evitando dobles disparos y fuego amigo sin código ([class_area3d](https://docs.godotengine.org/en/4.6/classes/class_area3d.html)):

- Hitbox del jugador: `collision_layer = capa "player_hitbox"`, `collision_mask = capa "enemy_hurtbox"`, `monitoring = true` (es el que escucha).
- Hurtbox del enemigo: `collision_layer = capa "enemy_hurtbox"`, `collision_mask = 0`, `monitorable = true` (se deja detectar, no escucha).
- Así solo el hitbox emite `area_entered` y llama `take_damage`; la hurtbox solo se deja detectar. El lado que escucha SIEMPRE necesita la capa del otro en su `mask`.

Clases y firmas (Godot 4.6, verificadas contra `class_area3d`):

- **`Area3D`** — señales `area_entered(area: Area3D)`, `area_exited(area: Area3D)`, `body_entered(body: Node3D)`. Propiedades `monitoring: bool` (esta Area detecta a otras) y `monitorable: bool` (otras Areas pueden detectarla). Métodos `get_overlapping_areas() -> Array[Area3D]`, `get_overlapping_bodies() -> Array[Node3D]`, `has_overlapping_areas() -> bool`.
- **`CollisionShape3D`** — hijo del Area3D; propiedad `disabled: bool`. Es lo que activas/desactivas entre swings (ver Pitfalls).
- **`Resource`** — base para `DamageInfo` con `@export`, serializable a `.tres` y editable en el inspector.
- **`RayCast3D`** — hitscan: `enabled`, `target_position: Vector3`, `is_colliding() -> bool`, `get_collider() -> Object`, `get_collision_point() -> Vector3`. Alternativa sin nodo: `get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D)`.
- **`Timer`** — i-frames y duración de hitbox de melee; señal `timeout`. Alternativa one-shot: `get_tree().create_timer(t).timeout` con `await`.

El daño se propaga por **señal** o por **método pato** (`if target.has_method("take_damage")`), nunca por referencias duras, para mantener el desacople del RPG.

### GDScript

`DamageInfo` como custom Resource (datos de golpe serializables, patrón confirmado en [Shaggy Dev](https://shaggydev.com/2026/04/08/godot-custom-resources/)):

```gdscript
# damage_info.gd
class_name DamageInfo
extends Resource

@export var amount: float = 10.0
@export var type: StringName = &"physical"
@export var knockback: float = 6.0
@export var resistances: Dictionary[StringName, float] = {}  # multiplicadores por tipo
var source: Node3D  # quién golpea; runtime, no exportado
```

Hitbox de melee dirigido por animación, con blacklist anti-doble-golpe por swing:

```gdscript
# hit_box_3d.gd
class_name HitBox3D
extends Area3D

@export var damage_info: DamageInfo

# El CollisionShape3D arranca con disabled = true.
# La AnimationPlayer llama start_attack()/end_attack() en keyframes (Call Method Track).
var _already_hit: Dictionary[int, bool] = {}  # por instance_id de la víctima

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func start_attack() -> void:
    _already_hit.clear()              # limpiar ANTES de habilitar
    $HitShape.disabled = false        # habilita el SHAPE, no el Area3D

func end_attack() -> void:
    $HitShape.disabled = true

func _on_area_entered(area: Area3D) -> void:
    # owner solo apunta a la víctima si la hurtbox vive dentro de una escena
    # instanciada cuyo root lleva take_damage; si se añadió en runtime sin owner,
    # area.owner es null. Fallback robusto al padre directo.
    var victim: Node = area.owner if area.owner != null else area.get_parent()
    if victim == null:
        return
    var id := victim.get_instance_id()
    if _already_hit.has(id):          # un golpe por víctima por swing
        return
    _already_hit[id] = true
    if victim.has_method("take_damage"):
        # source es transitorio por golpe: duplica para no mutar el .tres compartido.
        var info := damage_info.duplicate() as DamageInfo
        info.source = owner as Node3D
        victim.take_damage(info)
```

Receptor con i-frames y knockback sobre `CharacterBody3D`:

```gdscript
# health_component.gd
class_name HealthComponent
extends Node

signal died
signal health_changed(current: float, max_value: float)

@export var max_health: float = 100.0
@export var iframe_time: float = 0.6
@onready var _iframes: Timer = $IFrameTimer

var _health: float

func _ready() -> void:
    _health = max_health
    _iframes.one_shot = true          # i-frames de un solo disparo; no auto-repite

func take_damage(info: DamageInfo) -> void:
    if not _iframes.is_stopped():
        return                        # invulnerable durante i-frames
    var mult: float = info.resistances.get(info.type, 1.0)
    _health = maxf(_health - info.amount * mult, 0.0)
    health_changed.emit(_health, max_health)
    _apply_knockback(info)
    _iframes.start(iframe_time)
    if _health <= 0.0:
        died.emit()

func _apply_knockback(info: DamageInfo) -> void:
    var body := owner as CharacterBody3D
    if body == null or info.source == null:
        return
    var dir := body.global_position - info.source.global_position
    dir.y = 0.0
    body.velocity += dir.normalized() * info.knockback
```

Ranged hitscan sin nodo (mejor para varios disparos por frame):

```gdscript
const HURTBOX_LAYER := 4  # bit de la capa "enemy_hurtbox"

func fire_ray(from: Vector3, to: Vector3, info: DamageInfo) -> void:
    var space := get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.collision_mask = HURTBOX_LAYER
    q.collide_with_areas = true   # las hurtboxes son Area3D; por defecto es false
    q.collide_with_bodies = false # solo nos interesan las areas, saltamos cuerpos
    var hit: Dictionary = space.intersect_ray(q)  # {} si no golpea nada
    if hit.is_empty():
        return
    var collider: Object = hit["collider"]
    if collider.has_method("take_damage"):
        collider.take_damage(info)
```

### C# (.NET 8)

Equivalente idiomático. Señales como `[Signal]` delegates, `[Export]`, y `[GlobalClass]` para que el `Resource` aparezca en el inspector:

```csharp
// DamageInfo.cs
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class DamageInfo : Resource
{
    [Export] public float Amount { get; set; } = 10.0f;
    [Export] public StringName Type { get; set; } = "physical";
    [Export] public float Knockback { get; set; } = 6.0f;
    [Export] public Dictionary<StringName, float> Resistances { get; set; } = new();
    public Node3D Source { get; set; } // runtime
}
```

```csharp
// HitBox3D.cs
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class HitBox3D : Area3D
{
    [Export] public DamageInfo DamageInfo { get; set; }

    private readonly Dictionary<ulong, bool> _alreadyHit = new();
    private CollisionShape3D _shape;

    public override void _Ready()
    {
        _shape = GetNode<CollisionShape3D>("HitShape");
        // Monitoring debe ser true o AreaEntered NUNCA dispara.
        Monitoring = true;
        AreaEntered += OnAreaEntered;
    }

    public void StartAttack()
    {
        _alreadyHit.Clear();
        _shape.Disabled = false;
    }

    public void EndAttack() => _shape.Disabled = true;

    private void OnAreaEntered(Area3D area)
    {
        Node victim = area.Owner;
        if (victim == null) return;
        ulong id = victim.GetInstanceId();
        if (_alreadyHit.ContainsKey(id)) return;
        _alreadyHit[id] = true;
        if (victim.HasMethod("take_damage"))
            victim.Call("take_damage", DamageInfo);
    }
}
```

Gotchas C#:

- `AreaEntered` solo se emite si `Monitoring = true` (error frecuente de principiantes en el lado que escucha).
- **Gotcha 4.6 (C#):** al migrar de 4.5, varias propiedades de *nombre de animación* de `AnimationPlayer` pasaron de `String` a `StringName` (GH-110767): `current_animation`, `assigned_animation`, `autoplay`, `get_queue()` y el parámetro de la señal `current_animation_changed`. Pasar un `string` literal a métodos que toman `StringName` sigue compilando (conversión implícita), pero **leer** esas propiedades como `string` rompe a nivel de fuente. Relevante si disparas ataques desde una Call Method Track.
- Usa `area.AreaEntered += OnAreaEntered;` o `Connect(Area3D.SignalName.AreaEntered, Callable.From<Area3D>(OnAreaEntered))`. Nunca `as` sin null-check.

### Nodos/clases 4.6

| Necesidad | Nodo / clase nativa 4.6 | Nota |
|---|---|---|
| Detectar golpe melee | `Area3D` + `CollisionShape3D` | señales `area_entered`/`area_exited` |
| Datos del ataque | `Resource` (`@export`, `[GlobalClass]`) | serializable a `.tres` |
| Filtrado hit vs hurt | `collision_layer` / `collision_mask` | sin casts en runtime |
| Ventana de swing | `CollisionShape3D.disabled` | toggle del SHAPE |
| Hitscan ranged | `RayCast3D` o `PhysicsRayQueryParameters3D` | nodo vs consulta directa |
| I-frames / duración | `Timer` o `create_timer().timeout` | señal `timeout` |
| Knockback | `CharacterBody3D.velocity` | empuje sobre el receptor |

### Pitfalls

- **Deshabilita el `CollisionShape3D`, NO el `Area3D`.** Al desactivar `CollisionShape3D.disabled` la engine lo retira de los tests de solapamiento; si tocas `monitorable`/`monitoring` del Area, el nodo sigue en el mundo físico y solo deja de reportar (las señales de Area3D son diferidas y `get_overlapping_areas` se actualiza una vez por paso físico, de ahí las race conditions) ([class_area3d](https://docs.godotengine.org/en/4.6/classes/class_area3d.html), [issue #53997](https://github.com/godotengine/godot/issues/53997)).
- **Doble golpe (race condition).** Un hitbox que solapa varias hurtboxes en el mismo frame dispara `area_entered` por cada una; con hurtboxes por hueso, un puñetazo genera 4-6 señales. Solución: diccionario blacklist por swing, **limpiado en `start_attack()` antes de habilitar el shape**, con clave = `instance_id` de la víctima.
- **Jolt (default en 4.6) + Area3D — issues abiertos reales:** [#106482](https://github.com/godotengine/godot/issues/106482) reporta gran impacto de rendimiento con muchos `Area3D` solapados **aunque `monitorable = false`**, porque `JoltArea3D` fija el motion_type del sensor a kinematic (hay [PR #106490](https://github.com/godotengine/godot/pull/106490) de mihe en curso); [#118047](https://github.com/godotengine/godot/issues/118047) confirma lag con Area3D solapadas en Jolt; [#109721](https://github.com/godotengine/godot/issues/109721) reporta `body_exited` inconsistente tras reposicionar CharacterBody3D. Implicación RPG: **no dejes decenas de hurtboxes activas permanentemente**; desactiva las de enemigos fuera de pantalla. Si ves comportamiento raro, prueba "Godot Physics" para aislar el bug ([#88441](https://github.com/godotengine/godot/issues/88441)).
- **`get_overlapping_areas()/bodies()` van un frame desfasados** respecto a las señales y no se actualizan en el instante del `area_exited` ([proposal #8610](https://github.com/godotengine/godot-proposals/issues/8610)). No los uses para decidir el golpe en el frame del exit.
- **`monitoring` debe ser `true`** en el lado que escucha o `area_entered` nunca dispara (frecuente en C#).
- **`emit_signal()` está desaconsejado** en 4.x; usa `mi_senal.emit(...)`.

### Addon vs construirlo

**Addon mantenido (4.x):** *Health, HitBoxes, HurtBoxes and HitScans* de cluttered-code, MIT, 2D y 3D. Provee `HurtBox3D`, `HitBox3D`, `HitScan3D` (extiende `RayCast3D`) y un componente `Health`. Versión actual v5.0.3 (agosto 2025); en v5 los componentes base llevan prefijo "Basic" y cambiaron nombres, además de variantes con múltiples tipos de daño y modificadores — **si vienes de v4.x, lee el CHANGELOG/wiki antes de actualizar a v5** por esos cambios de nombres ([GitHub](https://github.com/cluttered-code/godot-health-hitbox-hurtbox), [Godot Asset Store](https://store.godotengine.org/asset/cluttered-code/health-hitboxes-hurtboxes-hitscans/)).

- **Usa el addon** si tu combate es estándar (golpe → daño → curación) y quieres prototipar rápido. Cubre melee, hurt/hit y hitscan listos.
- **Constrúyelo tú** (es ~150 líneas) si necesitas `DamageInfo` rico (tipo, crítico, status), reglas de facción/fuego amigo, knockback con curvas, escalado por stats o integración con un sistema de turnos propio. El patrón es tan ligero que para mecánicas únicas rodar el tuyo da más control y evita atarte a los cambios de API del addon (que ya rompió nombres en v5). Punto medio: estudia el [demo de GDQuest](https://github.com/gdquest-demos/godot-4-hitbox-hurtbox) y el [godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg), y escribe tus propios `HitBox3D`/`HurtBox3D`/`HealthComponent`.

**Veredicto ponytail:** No construyas un "CombatManager" ni un motor de daño. Reusa `Area3D` + `CollisionShape3D` para hit/hurt, deja que `collision_layer`/`collision_mask` filtren sin un solo `is`/cast, modela el golpe como un `Resource` (`DamageInfo.tres`), y usa `Timer` para i-frames. Lo único que escribes a mano son ~3 scripts ligeros (`HitBox3D`, `HealthComponent`, `DamageInfo`); para combate estándar, ni eso: instala el addon de cluttered-code.

## 4. Stats / niveles / progresión

En Godot 4.6 no existe un nodo "Stat" nativo. El patrón idiomático es **datos como `Resource`, lógica en el `Node`**: defines tus stats como recursos serializables (`.tres`), expones sus valores con `@export`, recalculas derivados con `Curve`, y desacoplas la UI con `signal`. Casi todo lo que necesitas ya está en el engine; lo que construyes son ~150 líneas de pegamento, no una arquitectura.

### Enfoque nativo recomendado

Las piezas nativas que cubren el 100% del dominio:

- **`Resource` + `class_name`** — `extends Resource` con `class_name UnitStats` registra un tipo global, crea slots en el Inspector y permite guardar `.tres`. Es la base del patrón `BattlerStats` de GDQuest Open RPG ([godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg)) y del sistema modular de Minoqi ([tutorial](https://minoqi.vercel.app/posts/godot-4-tutorials/stat-system-godot-4-tutorial/)).
- **`signal` en el propio `Resource`** — un recurso puede declarar `signal stat_changed(name: StringName)` y emitirlo desde sus setters. **No dependas de la señal `changed` heredada**: históricamente no se emite de forma fiable al mutar propiedades por código (Issue [#30179](https://github.com/godotengine/godot/issues/30179)); emite tus propias señales.
- **`Curve`** (Resource editable en el Inspector) para **curvas de crecimiento de stats** (HP/ATK por nivel). Firmas 4.6: `sample(offset: float) -> float`, `sample_baked(offset: float) -> float`, `bake()`, propiedad `bake_resolution`, rangos `min_value`/`max_value` (eje Y) y `min_domain`/`max_domain`. El eje X normalizado por defecto es `[0,1]`, así que normalizas `level/max_level` antes de samplear ([class_curve](https://docs.godotengine.org/en/4.6/classes/class_curve.html)).
- **Fórmula (no `Curve`) para umbrales de XP** — `xp_for(level)` exponencial/poly. `Curve` no es una tabla por-nivel infinita; usarla así es un error frecuente ([hilo foro](https://forum.godotengine.org/t/sample-curve-beyond-1-infinite-curve-sample/40106)).
- **`Dictionary[StringName, float]`** (diccionario tipado 4.6) para resistencias: claves `StringName` (rápidas de comparar, casan con nombres de tipo de daño), valores `float`. Ojo: el tipado del valor solo aplica a `[]` y al `for`; métodos como `get()` siguen devolviendo `Variant`, así que anota el tipo al enlazar (`var resist: float = dict.get(...)`) ([class_dictionary](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)).
- **Autoload + bus de señales** (Observer) para `xp_gained` / `leveled_up` / `xp_changed`, desacoplando la lógica de stats de la UI — exactamente lo que hace GDQuest.

### GDScript

`stat.gd` — stat con modificadores y orden de operaciones explícito:

```gdscript
class_name Stat
extends Resource

signal stat_updated

@export var base_value: float = 0.0
var _modifiers: Array[StatModifier] = []

func value() -> float:
	var flat := base_value
	var percent := 0.0
	var mult := 1.0
	for m: StatModifier in _modifiers:
		match m.modifier_type:
			StatModifier.Type.ADD:         flat += m.amount
			StatModifier.Type.PERCENT_ADD: percent += m.amount
			StatModifier.Type.MULT:        mult *= m.amount
	# Orden fijado: ADD -> PERCENT_ADD agregado -> MULT
	return flat * (1.0 + percent) * mult

func add_modifier(m: StatModifier) -> void:
	_modifiers.append(m)
	stat_updated.emit()

func remove_modifier(m: StatModifier) -> void:
	_modifiers.erase(m)
	stat_updated.emit()
```

Curva de crecimiento por nivel — normaliza a `[0,1]`:

```gdscript
@export var hp_curve: Curve          # Inspector, eje Y = HP
@export var max_level: int = 50

func max_hp_at(level: int) -> int:
	if max_level <= 1:
		return int(round(hp_curve.sample_baked(0.0)))
	var t := float(level - 1) / float(max_level - 1)
	return int(round(hp_curve.sample_baked(t)))
```

Level-up que absorbe **múltiples** niveles (usa `while`, no `if`):

```gdscript
signal leveled_up(new_level: int)
signal xp_changed(current: int, required: int)

var level: int = 1
var current_xp: int = 0

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_for_next_level():   # while: una gema grande sube varios niveles
		current_xp -= xp_for_next_level()
		level += 1
		leveled_up.emit(level)
	xp_changed.emit(current_xp, xp_for_next_level())

func xp_for_next_level() -> int:
	return int(100.0 * pow(level, 1.5))        # fórmula, no Curve
```

Resistencias tipadas:

```gdscript
@export var resistances: Dictionary[StringName, float] = {
	&"fire": 0.25,   # 25% de reducción
	&"ice": -0.5,    # negativo = vulnerabilidad
}

func apply_damage(amount: float, type: StringName) -> float:
	return amount * (1.0 - resistances.get(type, 0.0))
```

### C# (.NET 8)

Reglas para que un `Resource` aparezca en "New Resource" y se serialice: clase **`partial`**, archivo propio con nombre = nombre de clase (case-sensitive), hereda de `Resource`, marcada `[GlobalClass]` ([C# global classes](https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/c_sharp_global_classes.html)).

```csharp
using Godot;

[GlobalClass]
public partial class UnitStats : Resource
{
    [Signal] public delegate void LeveledUpEventHandler(int newLevel);
    [Signal] public delegate void XpChangedEventHandler(int current, int required);

    [Export] public int Level { get; set; } = 1;
    [Export] public int CurrentXp { get; set; }

    // [Export]/[Signal] solo aceptan tipos Variant-compatibles: usa
    // Godot.Collections.Dictionary, NUNCA System.Collections.Generic.Dictionary.
    [Export] public Godot.Collections.Dictionary<StringName, float> Resistances { get; set; } = new();

    public int XpForNextLevel() => (int)(100.0 * Mathf.Pow(Level, 1.5));

    public void AddXp(int amount)
    {
        CurrentXp += amount;
        while (CurrentXp >= XpForNextLevel())   // while, igual que en GDScript
        {
            CurrentXp -= XpForNextLevel();
            Level += 1;
            EmitSignal(SignalName.LeveledUp, Level);
        }
        EmitSignal(SignalName.XpChanged, CurrentXp, XpForNextLevel());
    }

    public float ApplyDamage(float amount, StringName type)
    {
        float resist = Resistances.TryGetValue(type, out float r) ? r : 0.0f;
        return amount * (1.0f - resist);
    }
}
```

Gotchas C# confirmados:
- Los parámetros de `[Signal]` y los miembros `[Export]` deben ser **Variant-compatibles** (marshalling C#/C++); el diagnóstico GD0202 salta si no lo son ([GD0202](https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/diagnostics/GD0202.html)).
- Conectar señales con `+=` **no se autodesconecta**: o haces `-=` manual, o usas `Connect()` (que se limpia al liberar el nodo). Emitir señales custom externas dio errores documentados en Issue [#82268](https://github.com/godotengine/godot/issues/82268); prefiere `EmitSignal(SignalName.X, ...)`.
- **Gotcha 4.6 (C#)**: al migrar de 4.5, propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Un `string` literal sigue compilando por conversión implícita; **leer** esas propiedades como `string` rompe a nivel de fuente.

### Nodos/clases 4.6

| Necesidad | Pieza nativa 4.6 |
|---|---|
| Modelo de stats serializable | `Resource` + `class_name` / `[GlobalClass]` |
| Editar valores en editor | `@export` / `[Export]` |
| Notificar cambios a la UI | `signal` propio (no la heredada `changed`) |
| Crecimiento HP/ATK por nivel | `Curve` (`sample_baked`, `bake_resolution`) |
| Umbrales de XP | fórmula GDScript/C# (no `Curve`) |
| Resistencias / multiplicadores | `Dictionary[StringName, float]` / `Godot.Collections.Dictionary<StringName, float>` |
| Desacoplar lógica de UI | Autoload (bus de señales, patrón Observer) |
| Instancia única por enemigo | `Resource.duplicate(true)` o `resource_local_to_scene` |

### Pitfalls

- **Los `Resource` se comparten por referencia.** Un `.tres` se carga una vez; si das el mismo `UnitStats.tres` a 10 enemigos, **comparten HP**. Solución: `stats = stats.duplicate(true)` en `_ready()`, o marcar **Local to Scene** ([Shaggy Dev](https://shaggydev.com/2026/04/08/godot-custom-resources/)).
- **`duplicate(true)` no es totalmente profundo.** No duplica subrecursos almacenados dentro de propiedades `Array` o `Dictionary` (Issue [#74918](https://github.com/godotengine/godot/issues/74918)). Si tu `UnitStats` lleva `Array[StatModifier]`, duplica esos modificadores a mano.
- **`Local to Scene` tiene bugs propios.** Duplicar una instancia copia la *referencia* (Issue [#45350](https://github.com/godotengine/godot/issues/45350)); escenas heredadas duplican local-to-scene como overrides no deseados (Issue [#111807](https://github.com/godotengine/godot/issues/111807)). Para enemigos en runtime, `duplicate(true)` explícito es más predecible que el checkbox.
- **`Curve` solo mapea X en `[0,1]`** por defecto. No es tabla por-nivel; normaliza `level/max_level`. `sample_baked` cerca de offset 1.0 ha tenido imprecisiones (Issue [#76623](https://github.com/godotengine/godot/issues/76623)) — sube `bake_resolution` o usa `sample()` exacto si la precisión importa.
- **Level-up con `if` pierde niveles** cuando una ganancia grande de XP cubre varios. Usa `while` o una cola con `pop_front` ([hilo foro](https://forum.godotengine.org/t/level-up-system-player-gains-multiple-levels/70743)).
- **`changed` no se emite fiablemente** al mutar por código (Issue [#30179](https://github.com/godotengine/godot/issues/30179)) — emite señales propias (`stat_updated`).
- **`String` y `StringName` no son claves intercambiables** en un diccionario; sé consistente (`&"fire"` siempre, no `"fire"`).

### Addon vs construirlo

**Stats + modificadores + XP: constrúyelo tú.** Son ~150 líneas, están fuertemente acoplados a tu modelo de daño/resistencias, y los addons existentes arrastran deuda de versión: `Zennyth/EnhancedStat` está etiquetado **Godot 4.1** ([repo](https://github.com/Zennyth/EnhancedStat)) y `samdze/godot-modifiers-plugin` es genérico ([repo](https://github.com/samdze/godot-modifiers-plugin)). Como referencia de código real: `Stat`/`StatModifier` de Minoqi ([tutorial](https://minoqi.vercel.app/posts/godot-4-tutorials/stat-system-godot-4-tutorial/)) y `Stats.gd` de Godot-Action-RPG ([archivo](https://github.com/l-Il/Godot-Action-RPG/blob/main/Stats.gd)).

**Skill tree / grafo: aquí sí reutiliza.** El layout, las conexiones y el dibujo de líneas son lo tedioso. Usa **Worldmap Builder** (`don-tnowe/godot-worldmap-builder`, Asset Library [#2270](https://godotengine.org/asset-library/asset/2270)) con su nodo `WorldmapGraph`; si no encaja, `SeldonHh/Godot_skill_tree_maker` (4.4, [repo](https://github.com/SeldonHh/Godot_skill_tree_maker)) como referencia a migrar. Los **datos** de cada skill, siempre como `Resource` propio, sea cual sea la UI.

**Veredicto ponytail:** No construyas un "StatSystem framework", ni un nodo `Stat`, ni una clase de tabla de XP, ni tu propio editor de árbol de habilidades. Reusa `Resource` + `class_name`/`[GlobalClass]` para los datos, `Curve` para crecimiento de stats, una fórmula para XP, `Dictionary[StringName, float]` para resistencias, `signal` propio + un autoload bus para la UI, y `Worldmap Builder` (Asset Library #2270) si necesitas grafo de skills. Tu código se reduce a setters, `value()` y un `while` de level-up.

## 5. Inventario / items / equipo

Un inventario en Godot 4.6 no es una "estructura de datos" que tengas que inventar: es la combinación de tres piezas nativas que ya existen y están testeadas — **`Resource`** para definir items como datos (`.tres` data-driven), **`Dictionary[StringName, int]`** tipado para el stacking/los modifiers, y el **drag-and-drop nativo de `Control`** para la UI. No necesitas un addon para empezar, y casi nunca necesitas un "InventoryManager" custom monolítico.

### Enfoque nativo recomendado

**Item = `Resource`, no nodo.** Cada tipo de item es una clase `extends Resource` con `class_name` y campos `@export`. Cada item concreto se guarda como un `.tres` (clic-derecho en FileSystem → *New Resource* → tu clase aparece en el diálogo porque tiene `class_name`). El inventario guarda **una referencia al `Resource` + una cantidad**, nunca un nodo y nunca una copia del blueprint. La doc de [Resource](https://docs.godotengine.org/en/4.6/classes/class_resource.html) y los tutoriales de [StraySpark](https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide) coinciden en este patrón.

**Stacking y modifiers = `Dictionary[StringName, int]`.** La sintaxis de diccionario tipado confirmada en la [doc 4.6 de Dictionary](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html) es `Dictionary[K, V]`. Para mapear `id -> cantidad` o `stat -> bonus`, `Dictionary[StringName, int]` da chequeo de tipos en runtime y claves interned (comparación por puntero, ideal para IDs comparados a menudo). Clave práctica: **el acceso por punto (`dict.key`) no es fiable con claves `StringName`** — es azúcar para claves `String` — usa siempre indexación `dict[&"key"]` ([forum](https://forum.godotengine.org/t/is-dictionary-dot-syntax-my-dictionary-my-key-compatible-with-stringname-keys/104092)).

**UI = drag-and-drop nativo de `Control`.** Los tres métodos virtuales (firmas confirmadas en la [doc de Control](https://docs.godotengine.org/en/4.6/classes/class_control.html)):

```gdscript
func _get_drag_data(at_position: Vector2) -> Variant
func _can_drop_data(at_position: Vector2, data: Variant) -> bool
func _drop_data(at_position: Vector2, data: Variant) -> void
```

- `_get_drag_data` devuelve el dato arrastrable (o `null` si no hay nada). Aquí se llama a `set_drag_preview(control)` para el preview visual que sigue al cursor.
- `_can_drop_data` se invoca **continuamente** sobre el `Control` bajo el cursor: devuelves si ese slot acepta el dato (validar tipo, slot de equipo, espacio).
- `_drop_data` confirma el movimiento: quitar del origen, añadir al destino.

El patrón está documentado en [pdeveloper](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13) y en el inventario Tetris de [MobiusCode](https://mobiuscode.dev/posts/Drag-&-Drop-Tetris-Inventory-System-in-Godot/).

**Equipo = un contenedor separado del inventario.** El patrón recomendado por [Liquid Fire](https://theliquidfire.com/2024/10/23/godot-tactics-rpg-10-items-and-equipment/) y StraySpark: un set de slots `StringName` (HEAD, BODY, PRIMARY, SECONDARY, ACCESSORY), cada slot acepta solo items con el `equip_slot` correspondiente. Al equipar, se aplican los `modifiers` del item a un sistema de stats (un [`Stat extends Resource`](https://medium.com/@minoqi/modular-stat-attribute-system-tutorial-for-godot-4-0bac1c5062ce) con `base_value`, modificadores ordenados y `signal` de actualización para refrescar UI).

**Carga de la "BD" de items:** `ResourceLoader.load(path)`/`preload` para uno suelto, o recorrer un directorio de `.tres` con `DirAccess` y construir un `Dictionary[StringName, ItemData]` indexado por `id` (típicamente en un autoload/singleton).

### GDScript

```gdscript
# item_data.gd — el blueprint inmutable. Un .tres por item.
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var equip_slot: StringName                       # &"" si no es equipable
@export var modifiers: Dictionary[StringName, int] = {}  # stat -> bonus (4.6)
```

```gdscript
# inventory.gd — lógica pura, sin UI. Guarda referencia + cantidad.
class_name Inventory
extends Resource

signal changed

# id -> cantidad. Nota: este ejemplo mínimo apila también los no-apilables por
# simplicidad (un único contador por id). Para estado por instancia (durabilidad,
# encantamientos) guarda copias duplicate(true) en una colección aparte (Array[ItemData]
# o claves únicas por instancia), porque varias instancias colisionarían bajo la misma id.
@export var stacks: Dictionary[StringName, int] = {}
@export var items: Dictionary[StringName, ItemData] = {}  # id -> blueprint

func add_item(item: ItemData, amount: int = 1) -> int:
    items[item.id] = item
    if item.stackable:
        var current: int = stacks.get(item.id, 0)
        var allowed: int = mini(current + amount, item.max_stack)
        var added: int = allowed - current
        stacks[item.id] = allowed
        changed.emit()
        return added
    # No-apilable: en este ejemplo se cuenta igual por id (simplificación intencional).
    stacks[item.id] = stacks.get(item.id, 0) + amount
    changed.emit()
    return amount

func remove_item(id: StringName, amount: int = 1) -> void:
    if not stacks.has(id):
        return
    stacks[id] = maxi(stacks[id] - amount, 0)
    if stacks[id] == 0:
        stacks.erase(id)
        items.erase(id)
    changed.emit()

func count(id: StringName) -> int:
    return stacks.get(id, 0)
```

```gdscript
# inventory_slot.gd — un Control que arrastra y recibe items.
class_name InventorySlot
extends PanelContainer

@export var slot_id: StringName = &""   # &"" => slot de inventario genérico
var item: ItemData

@onready var _icon: TextureRect = $Icon

func set_item(value: ItemData) -> void:
    item = value
    _icon.texture = item.icon if item != null else null

func clear() -> void:
    set_item(null)

func _get_drag_data(_at_position: Vector2) -> Variant:
    if item == null:
        return null
    var preview := TextureRect.new()
    preview.texture = item.icon
    preview.custom_minimum_size = Vector2(48, 48)
    set_drag_preview(preview)
    return {&"source_slot": self, &"item": item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not (data is Dictionary and data.has(&"item")):
        return false
    var dragged: ItemData = data[&"item"]
    # Slot de equipo: solo acepta el equip_slot correcto. Genérico: acepta todo.
    return slot_id == &"" or dragged.equip_slot == slot_id

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    var source: InventorySlot = data[&"source_slot"]
    var dragged: ItemData = data[&"item"]
    source.clear()
    set_item(dragged)   # si slot_id != "", aquí aplicarías dragged.modifiers a stats
```

```gdscript
# Copia única cuando el item tiene estado mutable (durabilidad, encantamientos).
# Los Resource se comparten por referencia: duplicate(true) hace deep copy de las
# propiedades y de los subrecursos referenciados DIRECTAMENTE, PERO NO duplica los
# subrecursos guardados dentro de un Array o un Dictionary (issues #74918 / #82348).
# Si metes Resources mutables dentro de un Dictionary/Array, necesitas un deep_clone()
# manual o duplicar cada subrecurso explícitamente.
var unique := item_template.duplicate(true)
```

### C# (.NET 8)

```csharp
// ItemData.cs — blueprint como Resource. .tres en FileSystem.
using Godot;
using Godot.Collections; // ¡NO System.Collections.Generic para tipos Variant!

[GlobalClass]
public partial class ItemData : Resource
{
    [Export] public StringName Id { get; set; } = "";
    [Export] public string DisplayName { get; set; } = "";
    [Export] public Texture2D Icon { get; set; }
    [Export] public bool Stackable { get; set; } = true;
    [Export] public int MaxStack { get; set; } = 99;
    [Export] public StringName EquipSlot { get; set; } = ""; // "" si no equipable
    [Export] public Dictionary<StringName, int> Modifiers { get; set; } = new();
}
```

```csharp
// InventorySlot.cs — drag-and-drop idiomático en C#.
using Godot;
using Godot.Collections;

public partial class InventorySlot : PanelContainer
{
    [Export] public StringName SlotId { get; set; } = "";
    [Signal] public delegate void ChangedEventHandler();

    private TextureRect _icon;
    public ItemData Item { get; private set; }

    public override void _Ready() => _icon = GetNode<TextureRect>("Icon");

    public void SetItem(ItemData value)
    {
        Item = value;
        _icon.Texture = value?.Icon;
        EmitSignal(SignalName.Changed);
    }

    public void Clear() => SetItem(null);

    // El retorno es Variant (no Variant?): devolver default para "sin datos".
    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (Item == null)
            return default; // historial: issue #78507 sobre retorno null en C#

        var preview = new TextureRect
        {
            Texture = Item.Icon,
            CustomMinimumSize = new Vector2(48, 48),
        };
        SetDragPreview(preview);

        var data = new Dictionary
        {
            { "source_slot", this },
            { "item", Item },
        };
        return data; // Dictionary se convierte implícitamente a Variant
    }

    public override bool _CanDropData(Vector2 atPosition, Variant data)
    {
        // Variant.As<Dictionary>() NO devuelve null si el tipo no coincide:
        // devuelve un Dictionary vacío. Valida el tipo con VariantType para que
        // el guard sea tan robusto como `data is Dictionary` en GDScript.
        if (data.VariantType != Variant.Type.Dictionary)
            return false;
        var dict = data.As<Dictionary>();
        if (!dict.ContainsKey("item"))
            return false;

        var dragged = dict["item"].As<ItemData>();
        return SlotId == "" || dragged.EquipSlot == SlotId;
    }

    public override void _DropData(Vector2 atPosition, Variant data)
    {
        var dict = data.As<Dictionary>();
        var source = dict["source_slot"].As<InventorySlot>();
        var dragged = dict["item"].As<ItemData>();
        source.Clear();
        SetItem(dragged); // aquí aplicarías dragged.Modifiers a tus stats
    }
}
```

Notas C# idiomáticas (.NET 8):
- `[GlobalClass]` hace que `ItemData` aparezca en el diálogo *New Resource*, equivalente a `class_name` en GDScript.
- Usa **`Godot.Collections.Dictionary`/`Array`**, no las de `System.Collections.Generic`, para que crucen el límite engine/Variant. Leer datos arrastrados con `.As<T>()`.
- `_GetDragData` devuelve `Variant` no anulable: para "sin datos" devuelve `default` (no `null`). Esto fue causa del [issue #78507](https://github.com/godotengine/godot/issues/78507).
- **Gotcha 4.6 (C#):** al migrar de 4.5, propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()` → `StringName[]`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Un `string` literal sigue compilando por conversión implícita; **leer** esas propiedades como `string` rompe a nivel de fuente.

### Nodos/clases 4.6

- **`Resource`** + **`@export`** / **`[GlobalClass]`** — items como datos (`.tres`).
- **`Dictionary[StringName, int]`** — stacking y modifiers tipados ([doc 4.6](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)).
- **`Control`** + `_get_drag_data` / `_can_drop_data` / `_drop_data` / `set_drag_preview` — drag-and-drop nativo ([doc Control](https://docs.godotengine.org/en/4.6/classes/class_control.html)).
- **`GridContainer`** / **`PanelContainer`** / **`TextureRect`** — la rejilla de slots y el icono; sin código de layout custom.
- **`ResourceLoader.load`** / `preload` / **`DirAccess`** — cargar la BD de items.
- **`signal`** / `[Signal] delegate` — `changed` para refrescar UI sin polling.

### Pitfalls

- **Resources compartidos por defecto (la trampa #1).** 50 cofres apuntando al mismo `.tres` comparten estado. Si el item tiene estado mutable, `duplicate(true)` (deep) — pero ojo: `duplicate(true)` copia las propiedades y los subrecursos referenciados **directamente**, y NO los subrecursos guardados dentro de un `Array`/`Dictionary` (issues [#74918](https://github.com/godotengine/godot/issues/74918) / #82348); `duplicate()` simple tampoco copia subrecursos anidados ([issue #37222](https://github.com/godotengine/godot/issues/37222), [forum](https://forum.godotengine.org/t/duplicate-not-making-a-unique-copy-of-my-custom-resource/46404)). Si guardas Resources mutables dentro de colecciones, clónalos a mano. Pero si el item es inmutable (espada genérica), **NO dupliques**: guarda la referencia + cantidad y ya.
- **`resource_local_to_scene`** no siempre instancia una copia local fiable al duplicar instancias de escena ([issue #45350](https://github.com/godotengine/godot/issues/45350)); verifica que cada entidad con stats mutables tenga su propia copia.
- **`dict.key` con claves `StringName`** no es fiable — usa `dict[&"key"]` siempre.
- **No confundir blueprint con instancia.** Mutar el `.tres` muta todos los items de esa plantilla. El inventario referencia el blueprint; el estado va en la instancia/cantidad.
- **C#:** retorno `Variant` (no `null`) en `_GetDragData`; `Godot.Collections.*` no `System.*`; recompilar tras 4.6 por `String`→`StringName` en pistas de animación.

### Addon vs construirlo

| Opción | Estado 4.x | Cuándo usar |
|---|---|---|
| **GLoot** ([peter-kish](https://github.com/peter-kish/gloot)) | El más mantenido; 4.4+, testeado vs 4.7; constraints Grid/Weight/ItemCount; v3.0 en master (rompe con 2.x) | Inventarios grid/peso, prototipado rápido, sistema "universal" ya resuelto |
| **expressobits/inventory-system** ([repo](https://github.com/expressobits/inventory-system)) | Mantenido, modular, nodos, multiplayer | Si necesitas multiplayer y separación lógica/UI desde el día 1 |
| **Whimfoome/godot-InventorySystem** ([repo](https://github.com/Whimfoome/godot-InventorySystem)) | Basado en Resources 4.x | Alternativa ligera centrada en Resources |
| **wyvernbox** ([repo](https://github.com/don-tnowe/godot-wyvernbox-inventory)) | Godot 3 y 4, foco ARPG | Loot tipo Diablo / grid ARPG |
| **Nativo** (Resource + Control DnD) | — | RPG con reglas de equipo/modifiers propias, control total del data model |

Advertencia de migración: **GLoot v3.0 rompe compatibilidad con v2.x** — no actualices a ciegas un proyecto existente.

**Veredicto ponytail:** No construyas un "InventoryManager" singleton monolítico ni un sistema de drag-and-drop a mano ni una estructura de datos custom para stacking. Reutiliza lo nativo: items como `Resource` (`.tres`), `Dictionary[StringName, int]` tipado para stacks/modifiers, y los tres virtuales de `Control` (`_get_drag_data`/`_can_drop_data`/`_drop_data` + `set_drag_preview`) sobre `GridContainer`. Si lo que quieres es grid/peso ya resuelto, instala **GLoot** y no escribas nada. Solo construye el data model propio cuando tus reglas de equipo/stats lo justifiquen — y aun entonces, la UI sigue siendo `Control` nativo.

## 6. Diálogo y quests

Diálogo y quests son, en el fondo, **datos + estado + eventos**. La tentación es construir un grafo de nodos custom con su propio editor; el camino sólido en Godot 4.6 es no construir casi nada: `Resource` para los datos serializables, `signal` para desacoplar lógica de UI, y un **autoload (singleton)** que custodia el estado runtime y el save/load. Tres conceptos nativos cubren el 90% de un RPG ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources), [Coding Quests](https://codingquests.io/blog/godot-4-dialogue-system-tutorial)).

### Enfoque nativo recomendado

- **Datos como `Resource`** (`class_name DialogueLine extends Resource`, `class_name Quest extends Resource`). Se editan en el Inspector, se guardan como `.tres`/`.res` y versionan en git. Un grafo de diálogo ramificado es simplemente un `Resource` que referencia a otros vía `@export` (recursión de `Resource`) — patrón confirmado en el [foro oficial](https://forum.godotengine.org/t/resource-recursion-for-branching-and-repeating-dialog-system/52517).
- **Señales para desacoplar**: el manager emite `line_displayed`, `choices_presented`, `dialogue_ended`; la UI escucha. El manager **nunca** conoce la UI. Doc oficial 4.6: [Using signals](https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html).
- **Autoload (singleton)**: registrado en *Project Settings → Autoload*. `DialogueManager`/`QuestManager` mantienen el estado en memoria y escuchan eventos de gameplay. **Regla de oro**: jamás guardes estado de quest en nodos de escena — se pierde al recargar; vive en el `Resource` o en el autoload ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)).
- **Eventos, no polling**: conecta `enemy.died.connect(QuestManager.on_enemy_killed)` en lugar de revisar progreso en `_process`. Menos overhead y menos acoplamiento.
- **`Dictionary[K, V]` tipado (4.6)** para flags de conversación/mundo (`var flags: Dictionary[StringName, bool]`), y **`Expression`** para condiciones dinámicas sin hardcodear `if`.

### GDScript

```gdscript
# dialogue_line.gd — dato puro, sin nodos
class_name DialogueLine extends Resource

@export var speaker: String
@export_multiline var text: String
@export var choices: Array[DialogueChoice] = []   # vacío = avance lineal
@export var next_line: DialogueLine                # null = fin de la rama
```

```gdscript
# dialogue_choice.gd
class_name DialogueChoice extends Resource

@export var label: String
@export var next_line: DialogueLine
@export var condition: String = ""   # ej. "flags.has(&\"talked_to_elder\")"
```

```gdscript
# dialogue_manager.gd — autoload "Dialogue". NO conoce la UI.
extends Node

signal line_displayed(line: DialogueLine)
signal choices_presented(choices: Array[DialogueChoice])
signal dialogue_ended

var flags: Dictionary[StringName, bool] = {}

func start(line: DialogueLine) -> void:
    _advance(line)

func _advance(line: DialogueLine) -> void:
    if line == null:
        dialogue_ended.emit()
        return
    line_displayed.emit(line)
    var available := _filter(line.choices)
    if not available.is_empty():
        choices_presented.emit(available)

func choose(choice: DialogueChoice) -> void:
    _advance(choice.next_line)

func continue_line(line: DialogueLine) -> void:
    _advance(line.next_line)

func set_flag(key: StringName, value: bool = true) -> void:
    flags[key] = value

func _filter(choices: Array[DialogueChoice]) -> Array[DialogueChoice]:
    var out: Array[DialogueChoice] = []
    for c in choices:
        if c.condition.is_empty() or _eval(c.condition):
            out.append(c)
    return out

func _eval(condition: String) -> bool:
    var expr := Expression.new()
    if expr.parse(condition, ["flags"]) != OK:
        push_warning("Condición inválida: %s" % condition)
        return false
    var result: Variant = expr.execute([flags], self)
    if expr.has_execute_failed():
        push_warning("Fallo al evaluar: %s" % condition)
        return false
    return bool(result)
```

Quests con el mismo patrón, actualizadas por señal:

Cada `class_name` global vive en **su propio archivo** (GDScript permite un solo `class_name` por script):

```gdscript
# quest_objective.gd
class_name QuestObjective extends Resource
enum Kind { KILL, COLLECT, TALK, REACH }
@export var kind: Kind = Kind.KILL
@export var target: StringName
@export var required: int = 1
@export var progress: int = 0
func is_done() -> bool: return progress >= required
```

```gdscript
# quest.gd
class_name Quest extends Resource
@export var id: StringName
@export var title: String
@export var objectives: Array[QuestObjective] = []
func is_complete() -> bool:
    return objectives.all(func(o: QuestObjective) -> bool: return o.is_done())
```

```gdscript
# quest_manager.gd — autoload "Quests". Sin polling.
extends Node

signal objective_updated(quest: Quest, objective: QuestObjective)
signal quest_completed(quest: Quest)

var active: Array[Quest] = []

func on_enemy_killed(enemy_id: StringName) -> void:
    for q in active:
        for obj in q.objectives:
            if obj.kind == QuestObjective.Kind.KILL and obj.target == enemy_id and not obj.is_done():
                obj.progress += 1
                objective_updated.emit(q, obj)
                if q.is_complete():
                    quest_completed.emit(q)
```

### C# (.NET 8)

Mismo modelo, con idioma C# idiomático: `partial class : Resource/Node`, `[Export]`, `[Signal] delegate ...EventHandler`, `EmitSignal(SignalName.X, ...)`. La conexión a manejadores tipados se hace con el operador `+=` (confirmado por la [doc oficial de C# signals](https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/c_sharp_signals.html)).

```csharp
using Godot;

[GlobalClass]
public partial class DialogueLine : Resource
{
    [Export] public string Speaker { get; set; } = "";
    [Export(PropertyHint.MultilineText)] public string Text { get; set; } = "";
    [Export] public Godot.Collections.Array<DialogueChoice> Choices { get; set; } = new();
    [Export] public DialogueLine NextLine { get; set; }
}
```

```csharp
using Godot;

// Autoload "Dialogue". El delegate DEBE terminar en "EventHandler".
public partial class DialogueManager : Node
{
    [Signal] public delegate void LineDisplayedEventHandler(DialogueLine line);
    [Signal] public delegate void ChoicesPresentedEventHandler(Godot.Collections.Array<DialogueChoice> choices);
    [Signal] public delegate void DialogueEndedEventHandler();

    public void Advance(DialogueLine line)
    {
        if (line == null)
        {
            EmitSignal(SignalName.DialogueEnded);
            return;
        }
        EmitSignal(SignalName.LineDisplayed, line);
        if (line.Choices.Count > 0)
            EmitSignal(SignalName.ChoicesPresented, line.Choices);
    }
}
```

```csharp
// En la UI: conexión fuertemente tipada con +=, sin strings ni Callable manual.
public override void _Ready()
{
    var dlg = GetNode<DialogueManager>("/root/Dialogue");
    dlg.LineDisplayed += OnLineDisplayed;        // tipado, refactor-safe
    dlg.DialogueEnded += () => QueueFree();
}
private void OnLineDisplayed(DialogueLine line) { /* pintar UI */ }
```

`[GlobalClass]` va en las clases de datos `Resource` (`DialogueLine`, `DialogueChoice`, `Quest`...) para que aparezcan bajo *New Resource* en el editor; los `Node` manager de autoload **no** lo necesitan, porque se registran en *Project Settings → Autoload* y se instancian por ahí, no se crean desde el menú de Resources.

**Gotcha 4.6 (String → StringName)**: en 4.6 varias propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Si tus diálogos disparan animaciones por nombre (`player.Play("talk")`), **recompila el ensamblado C#** tras subir de 4.5; pasa los nombres como `StringName` (`new StringName("talk")` o el literal `&"talk"` en GDScript) para evitar conversiones implícitas costosas. Para conectar señales a métodos GDScript snake_case desde C#, sigue usando `Connect("line_displayed", Callable.From(...))`; para señales entre código C#, prefiere siempre `+=` o `EmitSignal(SignalName.X, ...)` y evita `Callable.Bind`/lambdas con args, históricamente conflictivos ([issue #71895](https://github.com/godotengine/godot/issues/71895)).

### Nodos/clases 4.6

- **`Resource`** — base de todo dato de diálogo/quest. `@export`/`[Export]`, `[GlobalClass]` para que aparezca en *New Resource*.
- **`Node`** (autoload) — host de `DialogueManager`/`QuestManager` y sus señales.
- **`signal` / `Object.connect(Callable)` / `emit`** — bus de eventos nativo. Doc: [Using signals 4.6](https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html).
- **`Expression`** — evalúa condiciones de elección/quest definidas como string en datos.
- **`Dictionary[StringName, bool]`** — typed dictionaries 4.6 para flags de estado.
- **`Callable.From(...)`** (C#) — conexión a manejadores cuando `+=` no aplica (interop con GDScript).

### Pitfalls

- **Estado en nodos de escena**: se pierde al recargar. Mantén progreso de quest y flags de diálogo en el `Resource` o en el autoload ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)).
- **Polling de objetivos en `_process`**: usa señales de gameplay (`enemy.died.connect(...)`); más barato y desacoplado.
- **Referencias circulares entre `Resource`** en grafos con ciclos/repetición: la serialización puede complicarse. Si necesitas ciclos, usa `next_id: StringName` + un `Dictionary[StringName, DialogueLine]` en vez de `@export` directo; reserva la recursión de `@export` para árboles acíclicos ([foro oficial](https://forum.godotengine.org/t/resource-recursion-for-branching-and-repeating-dialog-system/52517)).
- **Mezclar dos modelos de datos**: si adoptas Dialogic (Timelines) y además mantienes tu grafo de `Resource`, duplicas estado. Elige uno como fuente de verdad.
- **C# tras 4.5→4.6**: recompila por `StringName` en tracks de `AnimationPlayer`; no asumas que `string` se autoconvierte sin coste.
- **Versión de addon**: Dialogic 2 requiere ≥4.4 (corre en 4.6); Dialogue Manager 4 apunta a 4.6+. Fija la versión antes de depender de ella (parche actual ~4.6.3).

### Addon vs construirlo

El patrón `Resource` + señales + autoload son ~150 líneas bajo tu control total: ideal si quieres integración estrecha con tu propio save/load y condiciones específicas del RPG. Si el contenido lo escriben no-programadores o quieres ramificación rica sin construir un editor, reutiliza un addon:

| Addon | Para qué | Versión |
|---|---|---|
| [Dialogue Manager (nathanhoad)](https://github.com/nathanhoad/godot_dialogue_manager) | Diálogo "stateless" estilo guion con `if/elif/while`, `set`/`do`, condiciones inline | 4.6+ |
| [Dialogic 2](https://github.com/dialogic-godot/dialogic) | VNs/NPCs con retratos, editor visual de timelines | 4.4+ |
| [shomykohai/quest-system](https://github.com/shomykohai/quest-system) | Quests basadas en Resource, API testeada y extensible (`QuestSystemManagerAPI`), localización CSV/POT | 4.4+ |
| [Chevifier/QuestManager](https://github.com/Chevifier/QuestManager) | Quests, docs claras, arranque rápido | 4.2+ |
| [Questify (TheWalruzz)](https://github.com/TheWalruzz/godot-questify) | Editor visual de quests por grafos | 4.4+ |

**Enfoque híbrido** que recomienda la comunidad: usa el *backend* (parsing/runtime) de un addon y conecta **tu propia UI** a sus señales — evita acoplar tu HUD al estilo del addon.

**Veredicto ponytail:** no construyas un editor de grafos ni un formato de datos propio. Reutiliza `Resource` (datos) + `signal` + un autoload `Node` (estado y save/load), con `Expression` para condiciones y `Dictionary[StringName, bool]` para flags. Para quests serias, monta sobre [shomykohai/quest-system](https://github.com/shomykohai/quest-system); para diálogo ramificado rico, [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) con tu UI conectada a sus señales. Lo único que vale la pena escribir tú es el pegamento (~150 líneas) y la UI.

## 7. IA enemiga y navegación

La regla de oro de este dominio: **la navegación no se programa, se configura**. Godot 4.6 trae una pila de navegación 3D completa (servidor + nodos agente + avoidance RVO) que cubre patrol/chase/attack sin una sola línea de A\* propio. Lo único que vale la pena escribir a mano es la máquina de estados de comportamiento (y a veces ni eso). Todo lo demás es reusar nodos nativos.

> Nota de versión: `NavigationServer3D` sigue marcado como **experimental** en los docs de 4.6 ("may be changed or removed in future versions") y no recibió rediseño en 4.6 respecto a 4.4/4.5. La API de alto nivel (`NavigationAgent3D`) es estable en la práctica. La 4.6.1 incluyó correcciones de mantenimiento; consultá el changelog interactivo para los detalles de navegación ([release notes 4.6.1](https://godotengine.org/article/maintenance-release-godot-4-6-1/)).

### Enfoque nativo recomendado

La escena de un enemigo navegable se arma con estos nodos, ninguno custom:

- **`NavigationRegion3D`** — contiene un recurso **`NavigationMesh`**. Se hornea con el botón "Bake NavMesh" del editor o por código con `bake_navigation_mesh()`. Colecciona geometría de hijos según `geometry/parsed_geometry_type`. Ajusta `Agents/Radius` y `Cell Size` del `NavigationMesh` si los agentes se atascan en paredes ([intro nav 3D](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_introduction_3d.html), [navmeshes](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationmeshes.html)).
- **`CharacterBody3D`** — raíz del enemigo. Es el nodo correcto para un personaje cinemático con gravedad manual y `move_and_slide()`.
- **`NavigationAgent3D`** (hijo del `CharacterBody3D`) — el cerebro de pathfinding. API clave verificada en docs 4.6 ([NavigationAgent3D](https://docs.godotengine.org/en/4.6/classes/class_navigationagent3d.html)):
  - `target_position: Vector3` — destino. Tras asignarlo hay que llamar `get_next_path_position()` **una vez por frame físico** para que el agente actualice su estado interno de path.
  - `get_next_path_position() -> Vector3` — siguiente waypoint.
  - `is_navigation_finished() -> bool` — guarda principal antes de mover.
  - `is_target_reachable()`, `distance_to_target()`.
  - `set_velocity(velocity: Vector3)` — **solo para avoidance**.
  - Señales: `velocity_computed(safe_velocity: Vector3)`, `target_reached`, `navigation_finished`, `waypoint_reached`.
  - Avoidance: `avoidance_enabled`, `radius`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`, `max_speed`.
- **`Timer`** — repathing periódico (recalcular `target_position` cada ~0.2–0.5 s, no cada frame). Reusar el nodo `Timer` evita escribir un acumulador a mano.
- **`NavigationObstacle3D`** (opcional) — obstáculos dinámicos. **Limitación documentada:** solo afecta el *avoidance local*, NO replanifica el path global; los agentes no rodean obstáculos móviles ([obstacles](https://docs.godotengine.org/en/4.6/classes/class_navigationobstacle3d.html)).
- **`NavigationServer3D`** (capa baja, sin nodo agente) — `map_get_path(map, origin, target, optimize, navigation_layers=1) -> PackedVector3Array`. Útil para previsualizar rutas. Devuelve array **vacío** si no hay ruta: guardar siempre con `if not path.is_empty()` ([NavigationServer3D](https://docs.godotengine.org/en/4.6/classes/class_navigationserver3d.html)).

El flujo de avoidance RVO es: fijas `set_velocity(deseada)` → el servidor calcula `safe_velocity` → emite `velocity_computed` → en ese callback aplicas el movimiento real con `move_and_slide()` ([usando agentes](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html)).

### GDScript

Chase básico con guarda de path, gravedad manual y repathing por `Timer`. Sin avoidance (lo más común en un RPG con pocos enemigos):

```gdscript
extends CharacterBody3D
## Enemigo que persigue al jugador usando NavigationAgent3D nativo.
## Escena: CharacterBody3D > [NavigationAgent3D, Timer (repath), CollisionShape3D]

@export var speed: float = 4.0
@export var gravity: float = 9.8
@export var target: Node3D

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _repath_timer: Timer = $RepathTimer

func _ready() -> void:
	# El NavigationServer sincroniza de forma DIFERIDA: si fijamos target
	# en _ready() sin esperar, get_next_path_position() devuelve nuestra
	# propia posición y el enemigo no se mueve. Esperar un frame físico.
	_repath_timer.timeout.connect(_on_repath)
	call_deferred("_setup")

func _setup() -> void:
	await get_tree().physics_frame
	_refresh_target()

func _on_repath() -> void:
	_refresh_target()

func _refresh_target() -> void:
	# Fijar SIEMPRE el target. is_target_reachable() mide contra el path ya
	# computado (el target anterior); usarla como guarda aquí crea un deadlock
	# huevo-gallina (devuelve false en la primera llamada y el enemigo no arranca).
	if target:
		_agent.target_position = target.global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _agent.is_navigation_finished():            # GUARDA: nada que hacer
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Obligatorio cada frame físico tras setear target: actualiza el path.
	var next: Vector3 = _agent.get_next_path_position()
	var dir: Vector3 = global_position.direction_to(next)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
```

FSM enum + `match` para patrol/chase/attack. Para pocos estados esto basta y no añade dependencias:

```gdscript
enum State { IDLE, PATROL, CHASE, ATTACK }

@export var state: State = State.PATROL

# Tabla de transiciones legibles para depurar (Dictionary tipado, desde 4.4).
var _state_names: Dictionary[State, StringName] = {
	State.IDLE: &"idle",
	State.PATROL: &"patrol",
	State.CHASE: &"chase",
	State.ATTACK: &"attack",
}

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:   _do_idle(delta)
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)
		State.ATTACK: _do_attack(delta)
```

Avoidance RVO (solo si tienes muchos enemigos apretados). Ojo al gotcha de gravedad:

```gdscript
func _ready() -> void:
	_agent.avoidance_enabled = true                # SIN esto, no hay señal
	_agent.velocity_computed.connect(_on_safe_velocity)

func _physics_process(delta: float) -> void:
	# Gravedad aparte: el avoidance 2D (use_3d_avoidance == false, por defecto)
	# ignora el eje Y, así que NO la metemos por set_velocity().
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _agent.is_navigation_finished():
		move_and_slide()
		return
	var next: Vector3 = _agent.get_next_path_position()
	var desired: Vector3 = global_position.direction_to(next) * speed
	_agent.set_velocity(desired)                   # NO mover aquí; esperar señal

func _on_safe_velocity(safe_velocity: Vector3) -> void:
	# El avoidance 2D devuelve safe_velocity.y == 0; si hiciéramos
	# velocity = safe_velocity mataríamos la gravedad cada frame (bug #108252
	# la pone en 0 también al terminar la nav). Reaplicamos solo x/z.
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()
```

### C# (.NET 8)

Equivalente idiomático. Señales como `delegate` con `[Signal]`/eventos `+=`, propiedades en PascalCase, `StringName` donde 4.6 lo pide:

```csharp
using Godot;

public partial class EnemyChaser : CharacterBody3D
{
    [Export] public float Speed { get; set; } = 4.0f;
    [Export] public float Gravity { get; set; } = 9.8f;
    [Export] public Node3D Target { get; set; }

    private NavigationAgent3D _agent;
    private Timer _repathTimer;

    public override void _Ready()
    {
        _agent = GetNode<NavigationAgent3D>("NavigationAgent3D");
        _repathTimer = GetNode<Timer>("RepathTimer");
        _repathTimer.Timeout += OnRepath;
        CallDeferred(MethodName.Setup);
    }

    private async void Setup()
    {
        // Issue #82209: MapGetPath/agente devuelven path vacío en C# si se
        // llama antes de la primera sincronización del servidor. Esperar.
        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        RefreshTarget();
    }

    private void OnRepath() => RefreshTarget();

    private void RefreshTarget()
    {
        // Fijar SIEMPRE el target. IsTargetReachable() mide contra el path ya
        // computado (deadlock huevo-gallina si se usa como guarda aquí).
        if (Target != null)
            _agent.TargetPosition = Target.GlobalPosition; // PascalCase
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector3 velocity = Velocity;

        if (!IsOnFloor())
            velocity.Y -= Gravity * (float)delta;

        if (_agent.IsNavigationFinished())
        {
            velocity.X = 0f;
            velocity.Z = 0f;
            Velocity = velocity;
            MoveAndSlide();
            return;
        }

        Vector3 next = _agent.GetNextPathPosition();
        Vector3 dir = GlobalPosition.DirectionTo(next);
        velocity.X = dir.X * Speed;
        velocity.Z = dir.Z * Speed;
        Velocity = velocity;
        MoveAndSlide();
    }
}
```

Para avoidance, la señal se conecta como evento: `_agent.VelocityComputed += OnSafeVelocity;` con firma `private void OnSafeVelocity(Vector3 safeVelocity)`.

**Gotcha 4.6 (C#):** al migrar de 4.5, propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Pasar un `string` literal sigue compilando por conversión implícita; **leer** esas propiedades como `string` rompe a nivel de fuente.

### Nodos/clases 4.6

| Nodo / clase | Rol | Nota 4.6 |
|---|---|---|
| `NavigationRegion3D` | Define el área navegable | Hornea `NavigationMesh` (botón o `bake_navigation_mesh()`) |
| `NavigationMesh` | Recurso de malla | Ajustar `Agents/Radius`, `Cell Size` |
| `NavigationAgent3D` | Pathfinding + path-following + avoidance | API estable; servidor subyacente experimental |
| `CharacterBody3D` | Cuerpo cinemático del enemigo | `move_and_slide()`, gravedad manual |
| `NavigationServer3D` | Capa baja `map_get_path()` | Experimental; sincronización diferida |
| `NavigationObstacle3D` | Obstáculo dinámico | Solo avoidance local, NO replanifica path global |
| `Timer` | Repathing periódico | Reusar en vez de acumular delta a mano |
| `Area3D` | DetectionArea / AttackRange | Disparan transiciones de la FSM |

Estructura de escena típica de los tutoriales 3D ([Coding Quests](https://codingquests.io/blog/godot-4-enemy-ai-tutorial)): `CharacterBody3D` con `NavigationAgent3D`, `DetectionArea` (`Area3D`), `AttackRange` (`Area3D`), `AnimationPlayer`, `CollisionShape3D` y un nodo `StateMachine` con estados hijos.

### Pitfalls

- **Sincronización diferida del servidor (causa #1 de bugs):** fijar `target_position` en `_ready()` sin esperar hace que `get_next_path_position()` devuelva tu propia posición y el enemigo no se mueva. Usar `await get_tree().physics_frame` o `call_deferred` ([foro: get_next_path_position no funciona](https://forum.godotengine.org/t/solved-navigationagent3d-get-next-path-position-is-not-working/91973)).
- **`get_next_path_position()` cada frame físico no es opcional:** actualiza el estado interno del path tras setear el target.
- **`velocity_computed` solo se emite con `avoidance_enabled == true`.** Si avoidance está apagado, NO uses el ciclo `set_velocity`/señal: aplica `velocity` directo y `move_and_slide()` ([proposal #5013](https://github.com/godotengine/godot-proposals/issues/5013), [#47337](https://github.com/godotengine/godot/issues/47337), [#81761](https://github.com/godotengine/godot/issues/81761)).
- **Avoidance descarta la Y al terminar la navegación**, rompiendo la gravedad. Reaplicar `velocity.y` manualmente tras recibir `safe_velocity` ([#108252](https://github.com/godotengine/godot/issues/108252)).
- **`map_get_path` devuelve array vacío en C#** si se llama antes de la primera sincronización o con el `RID` del mapa equivocado. Esperar `PhysicsFrame` antes del primer pathfind ([#82209](https://github.com/godotengine/godot/issues/82209)).
- **`NavigationObstacle3D` no replanifica rutas globales:** para bloqueos reales, vuelve a hornear la región o usa `affect_navigation_mesh`.
- **Path vacío:** `map_get_path` y los getters de path pueden devolver array vacío (target fuera del navmesh, mapa no sincronizado). Guardar con `is_empty()` / `is_navigation_finished()` antes de indexar.
- **`NavigationServer3D` sigue experimental** en docs 4.6: la API de bajo nivel puede cambiar entre versiones.

### Addon vs construirlo

- **Navegación: SIEMPRE nativa.** `NavigationAgent3D` + `NavigationRegion3D` + RVO cubre patrol/chase/attack y avoidance. No existe razón para un addon de pathfinding ni para escribir A\* propio.
- **FSM con pocos estados (idle/patrol/chase/attack): hazla con `enum` + `match`** (Idiom de arriba). Cero dependencias. La librería [godot-finite-state-machine](https://github.com/godot-addons/godot-finite-state-machine) es una alternativa minimalista por código si quieres estados como nodos.
- **Comportamiento que crece a behavior trees: [LimboAI](https://github.com/limbonaut/limboai)** (limbonaut), Behavior Trees + State Machines en C++ con editor visual, blackboard y debugger. Tiene build oficial **4.6+** en el Asset Library ([asset/4852](https://godotengine.org/asset-library/asset/4852)), activamente mantenido en 2026, y permite definir tasks/states en GDScript. Es lo más sólido del ecosistema cuando la jerarquía de conducta se vuelve compleja o quieres que diseñadores editen la IA sin tocar código.
- **Beehave:** no se confirmó compatibilidad 4.6 en la investigación; no recomendado sin verificar.

**Veredicto ponytail:** No escribas A\*, ni grid de navegación, ni sistema de waypoints, ni acumuladores de tiempo para repath. Reusa `NavigationRegion3D` + `NavigationMesh` (horneado) + `NavigationAgent3D` para todo el pathfinding y avoidance, y un `Timer` para el repathing. Lo único que justifica código propio es una FSM `enum`+`match` de cuatro estados; en cuanto la conducta crezca, instala **LimboAI** ([asset/4852](https://godotengine.org/asset-library/asset/4852)) en vez de construir tu propio árbol de comportamiento.

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

## 9. UI / HUD / menús

El error clásico al construir la interfaz de un RPG 3D es inventar un "sistema de UI" propio: managers, máquinas de estados de menús, posicionamiento absoluto en píxeles. Godot 4.6 ya trae casi todo resuelto con `Control`, `CanvasLayer`, `Theme`, contenedores y el sistema de foco. La regla es: que el HUD reaccione a señales del sistema de stats, que la disposición la hagan los contenedores y los anclajes, y que el estilo viva en un `Theme`.

### Enfoque nativo recomendado

**Capas.** El HUD de pantalla va sobre un `CanvasLayer` (capa 2D que se dibuja encima del mundo, ajena a la cámara 3D/2D). Dentro, una raíz `Control` (típicamente `MarginContainer` → `VBoxContainer`/`HBoxContainer`) y se distribuye con **anclajes + contenedores**, nunca con posiciones absolutas ([CanvasLayer docs](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html), [Canvas layers](https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html)). Las barras ancladas al mundo (vida sobre la cabeza de un enemigo) se resuelven con un `Sprite3D`/`SubViewport` + `TextureProgressBar` en billboard (receta de [KidsCanCode 3D Unit Healthbars](https://kidscancode.org/godot_recipes/4.x/3d/healthbars/index.html)).

**Barras de vida/recurso.** Tanto `ProgressBar` como `TextureProgressBar` derivan de `Range` ([ProgressBar docs](https://docs.godotengine.org/en/stable/classes/class_progressbar.html), [TextureProgressBar docs](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html)). Propiedades de `Range`: `value`, `min_value`, `max_value`, `step`, `page`, `ratio` (normalizado 0–1, lectura/escritura — escribirlo fija `value` proporcionalmente vía `set_as_ratio`), `exp_edit`, `rounded`; señal `value_changed(value: float)`. `TextureProgressBar` añade hasta tres texturas — `texture_under`, `texture_progress`, `texture_over` — más `fill_mode` (`FILL_LEFT_TO_RIGHT`, `FILL_BOTTOM_TO_TOP`, `FILL_CLOCKWISE`…), `tint_progress`, `nine_patch_stretch` y `stretch_margin_*`. Usa `TextureProgressBar` cuando quieres arte; `ProgressBar` cuando basta un rectángulo del tema.

**Animación suave.** No saltes el `value`. Anímalo con un `Tween` del SceneTree: `create_tween().tween_property(bar, "value", nuevo_hp, 0.2)`. El viejo `interpolate_property` no existe en 4.x.

**Theming.** Un recurso `Theme` para el estilo global ([Theme docs](https://docs.godotengine.org/en/stable/classes/class_theme.html)); para retoques puntuales, **theme overrides** o **theme type variations** (`Control.theme_type_variation`, un `StringName`) ([Theme type variations 4.6](https://docs.godotengine.org/en/4.6/tutorials/ui/gui_theme_type_variations.html)). Métodos de override por nodo: `add_theme_stylebox_override(name: StringName, stylebox: StyleBox)`, `add_theme_color_override`, `add_theme_font_override`, `add_theme_font_size_override`, `add_theme_constant_override`, y la familia `get_theme_*`/`has_theme_*`/`remove_theme_*`. Las type variations son la forma recomendada de tener un look "DangerButton" sin duplicar un `Theme` entero.

**Menú de pausa.** `get_tree().paused = true` pausa los nodos con `process_mode` en `PROCESS_MODE_INHERIT`/`PROCESS_MODE_PAUSABLE` ([Pausing games](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)). La raíz del menú (y su `CanvasLayer`) debe ser `PROCESS_MODE_WHEN_PAUSED` (solo corre en pausa) o `PROCESS_MODE_ALWAYS` (siempre). Enum: `Node.PROCESS_MODE_INHERIT / PAUSABLE / WHEN_PAUSED / ALWAYS / DISABLED`.

**Foco para gamepad/teclado.** El algoritmo por defecto elige el `Control` enfocable más cercano en la dirección pulsada por distancia en pantalla ([GUI navigation](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html)). API clave en `Control`: `focus_mode` (`FOCUS_NONE/CLICK/ALL` — `Button` es enfocable por defecto; `Label`/`Panel` no), `grab_focus()` (llámalo en `_ready()` o al mostrar un panel para sentar el foco inicial), y los overrides `focus_neighbor_top/bottom/left/right` (`NodePath`), `focus_next`, `focus_previous` cuando el algoritmo espacial se equivoca. Acciones por defecto: `ui_up/down/left/right/accept/cancel/focus_next/focus_prev`.

**Escalado multi-resolución.** Proyecto → Display → Window → Stretch: **Mode = `canvas_items`** (antes "2d") con **Aspect = `expand`** para HUDs que escalan con la resolución manteniendo nitidez; fija una resolución base. API en runtime: `Window.content_scale_mode` (`CONTENT_SCALE_MODE_DISABLED/CANVAS_ITEMS/VIEWPORT`), `content_scale_aspect`, `content_scale_factor`, `content_scale_size` ([Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)).

### GDScript

```gdscript
# stats.gd — autoload "Stats" o componente del jugador
extends Node

signal health_changed(current: int, maximum: int)

@export var max_health: int = 100
var _health: int = 100

func _ready() -> void:
    _health = max_health
    health_changed.emit(_health, max_health)

func take_damage(amount: int) -> void:
    _health = clampi(_health - amount, 0, max_health)
    health_changed.emit(_health, max_health)
```

```gdscript
# health_bar.gd — raíz TextureProgressBar dentro de un CanvasLayer
extends TextureProgressBar

@export var fill_time: float = 0.2

func _ready() -> void:
    # Decoplado: la barra solo escucha la señal, no consulta los stats.
    Stats.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, maximum: int) -> void:
    max_value = maximum
    var tw: Tween = create_tween()
    tw.tween_property(self, "value", current, fill_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

```gdscript
# pause_menu.gd — raíz Control; process_mode = PROCESS_MODE_WHEN_PAUSED en el Inspector
# (y el CanvasLayer padre en PROCESS_MODE_ALWAYS o WHEN_PAUSED)
extends Control

func _ready() -> void:
    hide()
    # Cableado explícito de foco para una columna de botones (gamepad).
    var buttons: Array[Button] = [%Resume, %Options, %Quit]
    for i in buttons.size():
        buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
        buttons[i].focus_neighbor_top    = buttons[(i - 1) % buttons.size()].get_path()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        var paused: bool = not get_tree().paused
        get_tree().paused = paused
        visible = paused
        if paused:
            (%Resume as Button).grab_focus()   # sin esto, el gamepad no navega
        get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
    get_tree().paused = false
    hide()
```

```gdscript
# danger_panel.gd — override de StyleBox y type variation sin duplicar el Theme
extends Panel

func _ready() -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("8b1a1a")
    add_theme_stylebox_override("panel", sb)
    # Reusar un look diseñado en el Theme, por nombre:
    var variants: Dictionary[StringName, StringName] = {
        &"warn": &"DangerButton",
        &"ok": &"PrimaryButton",
    }
    ($WarnButton as Button).theme_type_variation = variants[&"warn"]
```

### C# (.NET 8)

```csharp
using Godot;

public partial class Stats : Node
{
    [Signal]
    public delegate void HealthChangedEventHandler(int current, int maximum);

    [Export] public int MaxHealth { get; set; } = 100;
    private int _health = 100;

    public override void _Ready()
    {
        _health = MaxHealth;
        EmitSignal(SignalName.HealthChanged, _health, MaxHealth);
    }

    public void TakeDamage(int amount)
    {
        _health = Mathf.Clamp(_health - amount, 0, MaxHealth);
        EmitSignal(SignalName.HealthChanged, _health, MaxHealth);
    }
}
```

```csharp
using Godot;

public partial class HealthBar : TextureProgressBar
{
    [Export] public float FillTime { get; set; } = 0.2f;

    public override void _Ready()
    {
        // El delegado tipado del [Signal] genera el evento +=:
        GetNode<Stats>("/root/Stats").HealthChanged += OnHealthChanged;
    }

    private void OnHealthChanged(int current, int maximum)
    {
        MaxValue = maximum;
        // OJO: la propiedad va como ruta-string de Godot ("value"), no como miembro C#.
        CreateTween()
            .TweenProperty(this, "value", current, FillTime)
            .SetTrans(Tween.TransitionType.Sine)
            .SetEase(Tween.EaseType.Out);
    }
}
```

```csharp
using Godot;

public partial class PauseMenu : Control
{
    // En el Inspector: ProcessMode = WhenPaused (o por código abajo).
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.WhenPaused;
        Hide();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("ui_cancel"))
        {
            bool paused = !GetTree().Paused;
            GetTree().Paused = paused;
            Visible = paused;
            if (paused)
                GetNode<Button>("%Resume").GrabFocus(); // FocusMode = All (default en Button)
            GetViewport().SetInputAsHandled();
        }
    }

    private void OnDangerStyle(Panel panel)
    {
        var sb = new StyleBoxFlat { BgColor = new Color("8b1a1a") };
        // En 4.6 usa los nombres con prefijo Theme; el viejo AddStyleboxOverride sin
        // prefijo de algunos mirrors antiguos NO es la API actual.
        panel.AddThemeStyleboxOverride("panel", sb);
        GetNode<Button>("%WarnButton").ThemeTypeVariation = "DangerButton";
    }
}
```

**Gotcha 4.5→4.6 en C#:** en 4.6 (GH-110767) varias propiedades de nombre de animación de `AnimationPlayer` pasaron de `String` a `StringName`: `current_animation`, `assigned_animation`, `autoplay`, el retorno de `get_queue()` (ahora `StringName[]`) y el parámetro de la señal `current_animation_changed`. No es solo recompilar: es un cambio incompatible a nivel de fuente (ni binario ni source-compatible). Pasar un `string` literal a métodos que ahora toman `StringName` sigue compilando por conversión implícita, pero el código que LEE estas propiedades rompe: `string a = player.CurrentAnimation` (ahora `StringName`), handlers `void(string)` para `CurrentAnimationChanged`, y `string[] = player.GetQueue()` (ahora `StringName[]`). Ajusta esos tipos a `StringName`/`StringName[]` y recompila. Usa `StringName` (`&"..."` en GDScript) para nombres de override/variation y acciones de input.

### Nodos/clases 4.6

- `CanvasLayer` — capa de render para HUD/menús encima del mundo 3D.
- `Control` — base de toda UI: `focus_mode`, `grab_focus()`, `focus_neighbor_*`, `theme_type_variation`, `add_theme_*_override`.
- `MarginContainer`, `VBoxContainer`, `HBoxContainer` — disposición automática; nada de píxeles absolutos.
- `ProgressBar` / `TextureProgressBar` (← `Range`) — barras de vida/recurso; señal `value_changed`.
- `Theme`, `StyleBox`/`StyleBoxFlat` — estilo global y por nodo.
- `Button` — enfocable por defecto (`FOCUS_ALL`); base de menús navegables.
- `Tween` (`create_tween()`) — animación de `value` y fades.
- `Window` / project Stretch settings — `content_scale_mode`, `content_scale_aspect`.

### Pitfalls

- **Tween + pausa:** un `Tween` independiente se detiene cuando el árbol está en pausa aunque el nodo destino sea `PROCESS_MODE_ALWAYS` ([GH #81994](https://github.com/godotengine/godot/issues/81994)). Para fades del menú de pausa, crea el tween desde un nodo en `PROCESS_MODE_ALWAYS`; los tweens ligados a un nodo heredan su process mode. Solución directa: `var tw := create_tween(); tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` para que el tween corra durante la pausa; por defecto `TWEEN_PAUSE_BOUND` hereda el process_mode del nodo ligado.
- **CanvasLayer del menú sin process_mode correcto:** si olvidas poner el `CanvasLayer`/raíz del menú en `ALWAYS`/`WHEN_PAUSED`, los botones quedan inclicables en pausa (bug clásico de principiante).
- **Foco perdido al mostrar/ocultar:** mostrar un panel no le da foco solo; hay que `grab_focus()` en su primer control o la navegación con gamepad muere. El foco espacial solo encuentra nodos con `focus_mode != FOCUS_NONE` (salta `Label`/`Panel`).
- **`get_focus_neighbor()` solo devuelve asignaciones manuales** ([GH #77729](https://github.com/godotengine/godot/issues/77729)) — no sirve para leer el vecino auto-calculado.
- **Regresiones de `canvas_items`+`expand` en Android** entre 4.5.2 y 4.6.2 ([GH #118153](https://github.com/godotengine/godot/issues/118153)); prueba en dispositivo con tu parche objetivo (~4.6.3).
- **Sintaxis Tween antigua:** `interpolate_property`/`SceneTreeTween` está eliminada; usa `create_tween().tween_property(...)`. Muchos snippets viejos de foros son Godot 3.
- **Glow más brillante en 4.6:** afecta a cualquier HUD o fondo 3D luminoso contra el que compongas.

### Addon vs construirlo

- **UI de inventario → addon.** [gloot](https://github.com/peter-kish/gloot) (trae `CtrlItemSlot`, instalable por AssetLib, mantenido para 4.4+) y [expressobits/inventory-system](https://github.com/expressobits/inventory-system) (modular, multiplayer, items como Resources, lógica separada de UI) están activos para Godot 4.x. [GodotDynamicInventorySystem](https://github.com/alfredbaudisch/GodotDynamicInventorySystem) sirve más como referencia que como plugin drop-in.
- **Barras de vida/recurso → constrúyelas.** Es un `TextureProgressBar` + un manejador de señal + un tween. Sin addon. (`JarLowrey/TextureProgressOfSubunits` solo si necesitas barras segmentadas tipo "pips".)
- **Theme / menús / navegación de foco → nativo.** Son funciones de primera clase del motor; un addon solo añade riesgo de dependencia.
- **Regla:** addon para lo data-heavy, reutilizable y fácil de equivocar (inventario, diálogo); nativo para barras, themes, pausa y foco. Verifica `plugin.cfg`/README por compatibilidad 4.6 (o 4.4+) y cruza con [awesome-godot](https://github.com/godotengine/awesome-godot). Referencia integral: [godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg).

**Veredicto ponytail:** No construyas un "UIManager" ni un sistema de layout propio. Reusa `CanvasLayer` + `Control` con `MarginContainer`/`VBoxContainer`, barras con `TextureProgressBar` movidas por señal + `Tween`, estilo en un `Theme` con `theme_type_variation`, pausa con `get_tree().paused` + `PROCESS_MODE_WHEN_PAUSED`, y navegación con el sistema de foco nativo (`grab_focus`/`focus_neighbor_*`). Para inventario, instala gloot o expressobits/inventory-system en vez de programar grillas de slots.

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

## 11. Shaders para RPG

Los seis efectos clásicos de un RPG 3D (hit-flash, dissolve de muerte, outline/silueta, toon/cel, escudo Fresnel, agua) son cada uno entre 10 y 40 líneas de **Godot Shading Language** en texto (`.gdshader`). El error que atasca a una IA NO es escribir el efecto: es elegir mal el contenedor del material, compartir el recurso entre instancias, usar sintaxis de Godot 3, o no saber qué cambió en 4.6. Esta sección mapea cada efecto a la API exacta y blinda los puntos donde el render se rompe en silencio.

### Enfoque nativo recomendado

**Antes de escribir un shader, elige el contenedor.** El 80% de los bugs "no se ve / se ve raro / se aplica a todo" vienen de aquí:

| Necesitas... | Usa | Por qué |
|---|---|---|
| Reemplazar el look completo (toon, agua) | `ShaderMaterial` en el slot Material | Control total, sin PBR |
| Mantener PBR y AÑADIR un efecto encima (escudo, dissolve overlay) | `StandardMaterial3D` + `Material.next_pass` = `ShaderMaterial` | No reescribes el PBR |
| Outline/silueta de selección o hover | `StandardMaterial3D` → sección **Stencil** (modo Outline, nativo 4.5+) | Cero shader propio |
| Hit-flash en muchos enemigos que comparten material (Forward+/Mobile) | `instance uniform` + `set_instance_shader_parameter()` | No duplica recurso, va por MeshInstance3D — **NO en Compatibility/web** |
| Hit-flash en export **web/Compatibility** | `ShaderMaterial.duplicate()` por enemigo (`resource_local_to_scene = true`) + `set_shader_parameter()` | Compatibility no soporta `instance uniform` ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)) |

Hechos canónicos que evitan la mitad de los atascos:
- `ShaderMaterial` y `StandardMaterial3D` son hermanos (ambos heredan de `Material`/`BaseMaterial3D`). `Material.next_pass` encadena pasadas; **no todo tiene que ser ShaderMaterial**.
- `set_shader_parameter(param: StringName, value: Variant)` vive en `ShaderMaterial`, NO en `Shader`. En 4.x ya **no existe** `set_shader_param` (era Godot 3). Cada `uniform` del shader es un parámetro; el nombre debe coincidir literal.
- **Dos rutas distintas para el mismo uniform** y la IA las confunde: por código directo `set_shader_parameter("flash", v)` (sin barra); por Tween/AnimationPlayer la *property path* es `"shader_parameter/flash"` (con barra). Mezclarlas no da error fuerte: simplemente no pasa nada.
- `SCREEN_TEXTURE`, `DEPTH_TEXTURE` y `NORMAL_ROUGHNESS_TEXTURE` **fueron ELIMINADOS como built-ins** ([PR #70967](https://github.com/godotengine/godot/pull/70967)). Ahora son uniforms con hint: `uniform sampler2D screen_tex : hint_screen_texture;`. `SCREEN_UV`, `TIME`, `FRAGCOORD`, `VIEW`, `NORMAL`, `UV` siguen siendo built-ins.

**BREAKING 4.6 que rompe shaders existentes en silencio — y que la IA va a malinterpretar.** En 4.6, dentro de la struct `SceneData` de los **GLSL/compute crudos** (`.glsl`, `CompositorEffect`, `RenderingDevice`), `view_matrix` e `inv_view_matrix` cambiaron de `mat4` a `mat3x4` — y la guía de migración lo **omitió** inicialmente ([godot-docs#11744](https://github.com/godotengine/godot-docs/issues/11744)). Las tres lentes coinciden y verifiqué: esto **NO afecta** a `shader_type spatial` de alto nivel — ahí `VIEW_MATRIX`/`INV_VIEW_MATRIX` siguen siendo `mat4`. Los seis efectos RPG de esta sección son 100% `.gdshader` spatial/canvas_item, así que **no te afecta** salvo que escribas compute shaders. Si tocas `SceneData` en GLSL, el síntoma es geometría deformada o sombras desaparecidas tras actualizar de 4.5; reconstruye con `mat4(...)` o transpón según el orden de la multiplicación. Apunta a ≥4.6.3 (hubo regresiones de SDFGI/sky en snapshots intermedios, [godot#115599](https://github.com/godotengine/godot/issues/115599)).

### GDScript (hit-flash multi-enemigo, el patrón base de un RPG)

El efecto #1 de daño y el bug #1 de RPG: si 30 goblins comparten el `.tres` del `ShaderMaterial`, `set_shader_parameter("flash", 1.0)` los hace **parpadear a todos**. En **Forward+/Mobile** la solución correcta y barata es `instance uniform` + `set_instance_shader_parameter` (apunta al MeshInstance3D, no al recurso). **OJO — esto NO compila en Compatibility (= export web):** los `instance uniform` no están soportados ahí ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)), un shader con `instance uniform float flash` falla a compilar y el material no se renderiza. Para web, duplica el `ShaderMaterial` por enemigo (`material.duplicate()` con `resource_local_to_scene = true`) y usa `set_shader_parameter` normal. Ver bloque de ejemplos al final (incluye la rama web).

### Shader (.gdshader): los seis efectos

Todos verificados como Godot Shading Language 4.x/4.6. Resumen de los built-ins de salida que usan: `ALBEDO`, `EMISSION`, `ALPHA` (fragment); `DIFFUSE_LIGHT`, `SPECULAR_LIGHT` (light, con `+=`). Ver los archivos compilables en la sección de ejemplos.

Notas por efecto:
- **Hit-flash:** `ALBEDO = mix(base, flash_color, flash)`; añade `EMISSION` para que "pegue" con glow (en 4.6 el glow es más brillante). `source_color` en el uniform es **obligatorio** o el color se ve apagado.
- **Dissolve:** ruido + `if (n < dissolve) discard;` + borde `smoothstep`. Usa `render_mode cull_disabled` para no ver el interior hueco. En personajes skinned, samplea el ruido por posición de mundo (triplanar), no por UV, o las costuras se ven feas.
- **Outline:** primero intenta la sección **Stencil → Outline** nativa de `StandardMaterial3D` (cero código). Solo si necesitas X-ray "ver aliados a través de paredes" usa el patrón de dos pases con stencil (abajo). Para mobile barato, casco invertido (`cull_front` + inflar VERTEX por NORMAL).
- **Toon/cel:** sobrescribe `light()` y usa `DIFFUSE_LIGHT += ...` (con `+=`, nunca `=`). El atajo más barato si no necesitas control fino es `render_mode diffuse_toon, specular_toon;`.
- **Escudo Fresnel:** `pow(1.0 - dot(NORMAL, VIEW), power)`. El built-in es `VIEW` (no `VIEW_DIR`). `render_mode blend_add, unshaded, depth_draw_never`.
- **Agua:** desplazamiento en `vertex()`, foam con `hint_depth_texture`. El depth NO es lineal; hay que reconstruir (ver pitfalls). Evítala en el export web (Compatibility).

### Shader (.gdshader): outline por stencil (4.5+, solo si el modo nativo no basta)

Verificado: `stencil_mode write, compare_always, 1;` en el material base y `stencil_mode read, compare_not_equal, 1;` en el `next_pass`. El pase 2 va en el **Next Pass** del material base, o no se ve nada. Ver ejemplo `outline_stencil_pass2.gdshader`.

### Pitfalls y mensajes de error literales

| Mensaje / síntoma | Causa | Fix |
|---|---|---|
| `Unknown identifier in expression: 'SCREEN_TEXTURE'` (o `DEPTH_TEXTURE`) | sintaxis Godot 3 | declara `uniform sampler2D t : hint_screen_texture;` |
| `Unknown identifier in expression: 'VIEW_DIR'` | built-in inventado | es `VIEW` |
| `Invalid call. Nonexistent function 'set_shader_param'` (GDScript) | API Godot 3 | usa `set_shader_parameter()` |
| `Varying must be assigned before using!` | usas un varying en `fragment()`/`light()` sin asignarlo en `vertex()` | declara el varying global, asígnalo SOLO en `vertex()`, léelo en `fragment()` ([#50464](https://github.com/godotengine/godot/issues/50464)) |
| `Expected constant expression after '='` | `const float x = 1.0/1024.0;` o `const ... = pow(x,y);` el parser no evalúa esa aritmética | precalcula el literal o usa un `uniform` ([#33840](https://github.com/godotengine/godot/issues/33840), [#81391](https://github.com/godotengine/godot/issues/81391)) |
| Crash editor `Index is out of bounds` | un `sampler2D` con hint seguido de otro sin hint | pon hints explícitos en todos los samplers contiguos ([#67493](https://github.com/godotengine/godot/issues/67493)) |
| Toda la horda parpadea al herir a uno | `ShaderMaterial` compartido + `set_shader_parameter` | `instance uniform` + `set_instance_shader_parameter` (o `duplicate()` / `local_to_scene`) |
| Flash no se ve / shader no compila en export web | `instance uniform` no soportado en Compatibility ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)) | usa material duplicado por enemigo (`resource_local_to_scene`) + `set_shader_parameter` |
| Instance uniform "contamina" el outline | bug `next_pass`: modificar un instance uniform afecta al del next_pass | no reuses el mismo nombre entre pases ([#83472](https://github.com/godotengine/godot/issues/83472)) |
| `next_pass` ShaderMaterial sobre StandardMaterial3D solo muestra albedo | bug histórico ([#76537](https://github.com/godotengine/godot/issues/76537)) | invierte el orden (base = ShaderMaterial) o verifica `render_mode`/blend del next_pass |
| Foam de agua cambia con la cámara | `texture(depth_tex,uv).r` es depth NDC no-lineal, no metros | reconstruye con `INV_PROJECTION_MATRIX` (ver código) |
| Agua/escudo OK en Forward+, roto en web | Compatibility usa NDC OpenGL; `ndc.z` puede necesitar `raw*2.0-1.0` | rama por renderer o evita screen/depth en web |
| Pantalla negra al cambiar resolución | coexisten `hint_depth_texture` + `hint_screen_texture` | no los mezcles en escenas con resize ([#97728](https://github.com/godotengine/godot/issues/97728)) |
| Líneas rosa gridded con screen texture en web | bug Compatibility ([#79914](https://github.com/godotengine/godot/issues/79914)) | evita screen-space en el build web |
| Outline desaparece en export web | stencil no soportado en Compatibility | fallback a casco invertido o post-proceso |
| Sombra inconsistente con la malla disuelta | `discard` ocurre en el pase regular (tratado a menudo como transparente), así que su comportamiento de sombra no es fiable | para sombras opacas correctas usa `ALPHA` + `ALPHA_SCISSOR_THRESHOLD` (mantiene la malla en el pipeline opaco); [#58924](https://github.com/godotengine/godot/issues/58924) documenta el historial de sombras de alpha-scissor (era el scissor el que fallaba, ya corregido) |

### Cómo no quedarte atascado (pasos de decisión)

1. **¿2D/HUD o mundo 3D?** → `shader_type canvas_item` vs `spatial`. RPG: el mundo es `spatial`, el post-proceso/HUD va en un `canvas_item` sobre un `CanvasLayer`.
2. **¿Reemplazo el material o lo añado encima?** Añadir = `Material.next_pass`. No conviertas un PBR funcional en ShaderMaterial solo para un overlay.
3. **¿Outline?** Primero prueba `StandardMaterial3D` → Stencil → Outline (nativo). Solo escribe shader si necesitas X-ray.
4. **¿El efecto se dispara por instancia (flash, dissolve por enemigo)?** → `instance uniform` + `set_instance_shader_parameter`, NUNCA `set_shader_parameter` sobre recurso compartido.
5. **¿Uso pantalla/profundidad (agua, escudo con intersección, distorsión)?** Asume que se rompe en web (Compatibility). Declara los uniforms con `hint_screen_texture`/`hint_depth_texture`, reconstruye depth lineal, y ten un fallback sin screen-space para el export web.
6. **¿Web?** Renderer = Compatibility, y **web no tiene C#** → escribe la lógica de disparo en GDScript. Sin stencil, sin agua refractiva fiable, y **sin `instance uniform`** ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)): el hit-flash por instancia (el efecto estrella de esta sección) NO compila en web — usa `ShaderMaterial.duplicate()` por enemigo (`resource_local_to_scene = true`) + `set_shader_parameter`.
7. **¿Toca compute/GLSL crudo con `SceneData`?** Solo entonces te afecta `mat3x4`. Para `.gdshader` ignóralo.

### Addon vs construirlo

**Construir** los seis efectos: cada uno es <40 líneas, dependen de tus uniforms/pipeline, y un addon añade acoplamiento sin ahorro. Copia de [godotshaders.com](https://godotshaders.com) y adapta a 4.6 (verifica que no use `SCREEN_TEXTURE` viejo). **Excepción razonable:** una librería de funciones noise/fresnel vía `#include`, y para **agua realista/SSR** sí considerar un asset 4.6 verificado por la complejidad de depth+refracción. **Reusar antes que escribir:** outline (sección Stencil nativa), toon básico (`diffuse_toon`/`specular_toon`), y ruido (`NoiseTexture2D`/`FastNoiseLite` seamless en vez de generar ruido en el shader).

Texto (`.gdshader`) sobre VisualShader para todo: versionable en git, diffeable en PRs, y VisualShader no expone `stencil_mode` ni `light()` custom de forma completa.

**Veredicto ponytail:** el mejor shader es el que no escribes — outline con la sección Stencil nativa de `StandardMaterial3D`, toon con `render_mode diffuse_toon`, ruido con `NoiseTexture2D`. Cuando sí escribas, son 30 líneas: declara tus uniforms con `source_color`/`hint_*`, dispáralos por instancia con `set_instance_shader_parameter` (no revientes la horda entera — pero en web/Compatibility no hay `instance uniform`: ahí duplica el material por enemigo), y recuerda que `SCREEN_TEXTURE` murió en Godot 3. El `mat3x4` de 4.6 es un susto de compute, no de tus efectos.

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

## 14. Depuración y profiling

Un RPG 3D es el peor caso para depurar: cientos de nodos vivos, cambios de escena constantes (overworld ↔ combate ↔ menús), instanciado masivo de enemigos/loot/proyectiles y un autoload que sobrevive a todo. Aquí se acumulan los leaks y los lag spikes. Godot 4.6 trae herramientas integradas potentes (ObjectDB Profiler, Visual Profiler, Tracy/Perfetto/Instruments oficiales, botón Step Out); el error que atasca a una IA es ignorarlas y "tirar prints".

### Enfoque nativo recomendado

No construyas un sistema de depuración propio. En 4.6 todo lo que necesitas ya viene integrado. Pirámide canónica, en orden:

1. **Errores/warnings del panel Debugger** (pestaña *Errors*): clic en el error salta a la línea con stack expandible.
2. **Breakpoints + stepping** (F9 / palabra clave `breakpoint`), ahora con **Step Out** (nuevo en 4.6).
3. **Backtraces programáticos** (`print_stack`, `get_stack`, `print_debug`).
4. **Monitors + Profiler + Visual Profiler** para lag.
5. **ObjectDB Profiler** (nuevo en 4.6) para leaks / orphan nodes.
6. **Tracy / Perfetto / Apple Instruments** (oficiales en 4.6) para microsegundos por hilo, solo cuando el cuello de botella está en el engine.

**Decisión rápida — cuelgue vs lag (son dos flujos distintos):**

- **HANG (freeze total):** casi siempre bucle infinito o recursión de señales (A emite B, B reemite A). El stepping no ayuda si ya colgó. Corre desde terminal con `godot --verbose --path /ruta` y mira la última línea antes del freeze; pon un `breakpoint` antes de la sección sospechosa y haz Step Over; mete un contador guardia (`assert(_guard < 100000, ...)`).
- **LAG (FPS cae, responde):** Monitors → ¿sube *memory*, *nodes*, *orphans*, *draw calls*? Luego Visual Profiler para saber si es **CPU (izquierda) o GPU (derecha)**, y solo entonces el Profiler integrado ordenado por **Self Time** (no Total Time).

### El enemigo #1 del RPG: orphan nodes y ciclos RefCounted

El leak más común no es C++ ni texturas: es `remove_child()` sin `queue_free()`, o un nodo instanciado que nunca entra al árbol. Diferencia clave que origina la mayoría de leaks:

- `queue_free()` saca del árbol Y libera al final del frame.
- `remove_child()` **solo desvincula**; el nodo sigue vivo como orphan hasta que lo `free()`/`queue_free()` o lo reparentes. Pooling con `remove_child` es correcto **solo si** conservas la referencia para reusarlo.
- **Regla de oro:** nunca `extends Node` en algo que no metes en el SceneTree. Una clase de datos/utilidad debe ser `extends RefCounted` (se libera por conteo) o `Resource`.
- **Ciclo RefCounted** (A→B→A): el refcount nunca llega a 0; `queue_free` no aplica. Rómpelo con `weakref()` en una de las direcciones.

**Flujo 4.6 (ObjectDB Profiler, pestaña nueva en el panel Debugger):** toma un *snapshot* en el overworld → entra y sal de combate varias veces → toma otro snapshot → **diff**. Lo añadido sale en **verde**, lo eliminado en **rojo**; los orphans se agrupan aparte (no cuelgan de la raíz). Esto te da la **clase exacta** que no se libera. Vistas: *Nodes* (árbol + huérfanos), *RefCounted* (resalta ciclos), *Summary* (marca problemas). Complemento programático: `print_orphan_nodes()`. Al cerrar el juego, `ERROR: ObjectDB instances leaked at exit (run with --verbose for details)` confirma un leak; relanza con `--verbose` para el stack de creación.

### GDScript

Ver ejemplo completo `debug_tools.gd` (custom monitors, backtraces, asserts, toggles de visualización, chequeo de leaks).

### C# (.NET 8)

Ver ejemplo `DebugTools.cs`. Nota: **web NO tiene C#** (renderer Compatibility); si exportas a web, todo el debug en C# desaparece, usa GDScript. `assert` de GDScript no existe en C#: usa `System.Diagnostics.Debug.Assert` (también se elimina en build Release, mismo riesgo de side-effects).

### Pitfalls y mensajes de error literales

- **`assert()` se strippea COMPLETO en release.** Si metes lógica con efectos secundarios (`assert(spawn_enemy())`), funciona en el editor y **el enemigo nunca aparece en el export**. Además `assert` es palabra clave, no función: no la uses como expresión (`var a = assert(...)` → error de parser) y el segundo argumento debe ser un String constante.
- **`get_stack()` / `print_stack()` / `print_debug()` devuelven vacío o no hacen nada sin servidor de debug.** No funcionan en release, ni en build debug exportada no conectada, ni desde un `Thread`. Para release/crash reports activa `ProjectSettings → debug/settings/gdscript/always_track_call_stacks` (+ `Engine.capture_script_backtraces()`). Salvedad verificada (godot#106484): en exports release los números de línea del backtrace son incorrectos (apuntan a la firma de la función) — usa `function`, no `line`.
- **Firma OBSOLETA de Godot 3 en `add_custom_monitor`** — el error que más comete una IA: `add_custom_monitor("Player Health", self, "_get_health")`. En Godot 4 es `(id: StringName, callable: Callable, arguments := [])`. La vieja produce `Invalid type in function 'add_custom_monitor': argument 2 should be Callable`. Pasa un Callable: `_get_health` en GDScript, `new Callable(this, MethodName.X)` o `Callable.From(...)` en C#.
- **`Custom monitor 'X' already exists.`** Re-registrar el mismo id (autoload que sobrevive, `_ready()` que corre dos veces tras reparenting). Protégete con `if not Performance.has_custom_monitor(id):` y limpia en `_exit_tree()`.
- **El callable de un monitor debe devolver número >= 0.** La doc lo exige explícitamente: ha de devolver un entero o flotante cero o positivo; devolver String/null produce un valor inválido y rompe la gráfica en silencio. No hagas trabajo pesado dentro: se llama periódicamente (observer effect).
- **"Mis breakpoints no pausan."** Causas en orden: *Skip Breakpoints* activado (botón pegado entre sesiones); corriendo en export release / sin conexión al editor; breakpoint en un `Thread` secundario; línea no ejecutable. Verifica sesión activa en el panel Debugger; lanza con F5 **desde el editor Godot**, no desde VSCode (el Remote scene tree no aparece vía VSCode — godot-vscode-plugin#567).
- **Profiler vs Visual Profiler (error de categoría).** Profiler = tiempo CPU por función/script. Visual Profiler = coste del **renderer por frame** (GPU/render passes). Usar el equivocado persigue el cuello de botella incorrecto. Olvidar pulsar **Start** → "el profiler está vacío" (no graba por defecto).
- **`debug_collisions_hint` por código en runtime a menudo NO dibuja** si el menú del editor estaba OFF (godot#64353): el menú y la propiedad chocan. Usa **uno solo**: para depuración manual, el menú *Debug → Visible Collision Shapes*; para builds de debug, setea la propiedad **antes del primer frame físico** (togglear en caliente no re-genera shapes ya creados). En exports, `CollisionPolygon2D` solo muestra contorno (godot#99935 — no es tu bug). Desactiva estas visualizaciones antes de medir frame time.
- **"El Visual Profiler muestra tiempos CPU raros / Process tarda muchísimo sin justificación"** (godot#97473, #81435): a veces es tiempo de sincronización del frame contabilizado dentro de Process, o tiempos CPU del Visual Profiler poco fiables. Confirma con Self Time y un monitor de FPS. En **macOS/Metal el frametime GPU integrado está roto** (godot#102968): usa Apple Instruments.
- **"Solo es lento en debug."** El debugger remoto añade overhead por nodo/llamada (foro "DEBUG in 4.5 is unusable"). **Antes de optimizar, mide siempre con un export `template_release`.** Si el spike desaparece, era el debugger, no tu juego.
- **Spike de "primera vez"** (primer disparo / primer enemigo / primera escena de combate): carga lazy de recursos y **compilación de shaders**. Fix: `preload()` y shader pre-warming (instancia el material una vez fuera de cámara en la pantalla de carga).
- **Tracy no conecta:** requiere recompilar Godot con soporte de profiling (`tracy_enable=yes`), no sirve el binario oficial de release; la versión del viewer debe coincidir con el build. Sin `-fno-omit-frame-pointer -fno-inline -ggdb3` el callstack sale inútil.

### Cómo no quedarte atascado (checklist de decisión)

1. ¿Estás en **debug build conectada al editor** (F5)? Si no, breakpoints/`get_stack`/`print_stack`/`print_debug` no van.
2. ¿`Skip Breakpoints` activado por accidente?
3. ¿Solo pasa en debug? → mide en export release antes de tocar código.
4. Lag → Visual Profiler: ¿CPU (izq) o GPU (der)? Luego Profiler por **Self Time**.
5. ¿Usaste la firma **Callable** de `add_custom_monitor` (no objeto+string de Godot 3)? ¿El callable devuelve número >= 0? ¿Pulsaste **Start** en el Profiler?
6. Memoria crece → Monitors (orphan/object count) → **ObjectDB snapshot diff** → arregla `queue_free`/ciclos RefCounted. Un orphan NO aparece en el Remote scene tree (no está en el árbol) — míralo en el ObjectDB Profiler. No confíes en `get_orphan_node_ids()` (incompleto, godot#114854).
7. Cuelgue → `--verbose` + buscar bucle/señal recursiva + `breakpoint`.
8. ¿`assert()` con side-effects (se elimina en release) o usado como expresión?
9. Web: sin C#, Compatibility, conexión remota frágil → `--verbose` + consola del navegador.

### Addon vs construirlo

- **No construyas** un sistema de profiling propio: ObjectDB Profiler, Visual Profiler, Monitors y soporte Tracy/Perfetto/Instruments ya vienen integrados en 4.6. Construir era justificado en 3.x; en 4.6 es reinventar la rueda.
- **Sí construye tus custom monitors** con `Performance.add_custom_monitor` (enemigos vivos, tamaño del pool de proyectiles, entradas del caché de pathfinding, items de inventario): es API oficial, barato, se integra en la pestaña Monitors, y te permite **correlacionar el spike con tu dominio** ("el spike coincide con 120 enemigos vivos → spawner sin tope"). Instrúmentalo desde el día 1.
- **Addon recomendado** solo para HUD in-game de métricas en builds de QA sin editor conectado: **godot-debug-menu** (asset library #1902).
- **Tracy** solo cuando el integrado dice "está en render/física" pero no sabes qué función, o necesitas resolución por hilo (Jolt corre física en hilos). En **macOS**, Apple Instruments para GPU.

**Veredicto ponytail:** el mejor sistema de depuración es el que no escribes. 4.6 ya trae ObjectDB Profiler con snapshot diff, Visual Profiler CPU/GPU, Step Out y Tracy/Perfetto/Instruments oficiales — todo nativo. Lo único que vale la pena escribir tú son cuatro líneas de `add_custom_monitor` por cada métrica de tu RPG, porque el engine mide el engine y tú tienes que medir tu juego. Antes de optimizar nada, verifica que el problema no sea solo el overhead del debugger: exporta en release y vuelve a medir.

## 15. C# .NET 8 a fondo

Godot 4.6 (publicado 2026-01-27, ~4.6.3) ejecuta C# sobre **.NET 8 (LTS)**. Mono fue descontinuado: el runtime es .NET 8 puro. Hay tres choques que atascan a CASI todo dev/IA que llega de Unity, ASP.NET o GDScript, y conviene tratarlos como el núcleo del tema: (1) **source generators + `partial`**, (2) **marshalling vía Variant**, (3) **ciclo de vida `GodotObject` vs GC de .NET**. Una IA construyendo un RPG se queda atascada SIEMPRE en los mismos sitios; abajo van con su mensaje literal y su desatasque.

### Enfoque nativo recomendado

Antes de elegir lenguaje, una restricción dura que decide la arquitectura: **el web NO soporta C# en 4.6**. La causa es del runtime .NET, no del renderer: el runtime .NET hoy solo puede compilarse como "main module" y carece de código position-independent, así que no se embebe en el export WASM (issue abierto GH-70796). Aparte, el export web usa el renderer Compatibility, pero eso es ortogonal: el bloqueo de C# es del runtime, no del renderer. No hay flag que lo arregle. Si tu RPG 3D apunta a navegador, el core jugable va en GDScript o haces doble export.

Recomendación de reuso (ponytail) por encima de escribir código:
- **No escribas un `.csproj` a mano.** Deja que Godot lo cree: **Project > Tools > C# > Create C# solution**. El `Sdk="Godot.NET.Sdk/4.6.x"` y el `<TargetFramework>net8.0</TargetFramework>` los pone bien y evitas mismatches de versión.
- **No reimplementes señales/observabilidad ni reflexión de exports**: los source generators del `Godot.NET.Sdk` ya generan `SignalName`/`MethodName`/`PropertyName`, el helper `EmitSignalXxx`, y el registro de `[Export]`. Vienen dentro del SDK, no necesitas addon.
- **No reinventes async/corrutinas para gameplay simple**: `ToSignal` + un `CancellationTokenSource` basta. Solo para secuencias serias de combate/cinemáticas considera el addon GDTask.
- **Para datos hereda de `Resource`/`RefCounted`** (autogestión por refcount) y reserva `Node` para el árbol de escena. Menos código de liberación manual = menos `ObjectDisposedException`.

Cuándo C# y cuándo GDScript en un RPG 3D (consenso 2025-2026, ya no es "C# = rápido"):
- **C#** para el core CPU-intensivo: sistema de stats, IA de combate por turnos con muchas iteraciones, RNG determinista, A*/pathfinding a gran escala, serialización de saves grandes, y si el equipo viene de .NET (tooling Rider/VS, tests, generics).
- **GDScript tipado** para nodos de escena, UI, glue, hot-reload, y es el **único camino a web**.
- **Regla anti-atasco transversal:** cada cruce de la frontera C#↔engine paga marshalling Variant. No cruces en bucles calientes: cachea nodos en `_Ready` (no en `_Process`), y copia un `Godot.Collections.Array` a un `T[]`/`List<T>` de System antes de iterar miles de veces.

### GDScript

```gdscript
extends CharacterBody3D
@export var speed: float = 6.0
signal health_changed(old_hp: int, new_hp: int)
var hp := 100

func _physics_process(delta: float) -> void:
    velocity.x = Input.get_axis("left", "right") * speed
    move_and_slide()

func damage(amount: int) -> void:
    var old := hp
    hp -= amount
    health_changed.emit(old, hp)

func _ready() -> void:
    await get_tree().create_timer(1.5).timeout
    if is_instance_valid(self):
        position = Vector3.ZERO
```

### C# (.NET 8)

Ver bloque de ejemplos (`Player.cs`, `Inventory.cs`, `Game.csproj`). Puntos idiomáticos que NO son "GDScript traducido":
- **`delta` es `double`** en los overrides de C# (`_Process(double)`, `_PhysicsProcess(double)`), no `float`. Castea con `(float)delta` cuando lo multipliques por floats.
- API en **PascalCase**: `MoveAndSlide()`, `GetNode<T>()`, `_Ready()`, `Velocity`.
- Emite señales con el **helper tipado generado** `EmitSignalHealthChanged(old, hp)` (wrapper sobre `EmitSignal(SignalName.HealthChanged, ...)`); evita el string mágico `EmitSignal("HealthChanged", ...)`.
- `Velocity = Velocity with { X = ... }` (records/`with` de C# sobre el struct `Vector3`).

### Pitfalls y mensajes de error literales

**Build / toolchain (atasco día 1):**
- `error MSB4236: The SDK 'Godot.NET.Sdk/4.6.x' specified could not be found.` → (a) no hay **.NET 8 SDK** en el PATH de la sesión que lanzó Godot (clásico: PATH OK en SSH pero no en la sesión GUI). `dotnet --list-sdks` debe mostrar un 8.x. (b) Estás usando el binario **estándar** en vez de la build **".NET"/"Mono"** (`Godot_v4.6-stable_mono_*`); el editor estándar no abre proyectos C#. (c) El feed `nuget.org` no resuelve `Godot.NET.Sdk` (el primer restore necesita red). (GH-58955)
- `CS0246: The type or namespace name 'Vector3I' could not be found` → casi siempre `bin/`+`obj/` corruptos tras cambiar de versión de Godot, o nombre mal escrito (en 4.x es `Vector3I`/`Vector2I`, PascalCase). Borra `.godot/mono`, `bin/`, `obj/`, rebuild. (GH-68411)

**Source generators / `partial`:**
- `GD0001: Missing partial modifier on declaration of type '...' that derives from 'GodotObject'` → añade `partial`. Toda clase que derive de `GodotObject` (incl. `Node`, `Resource`, `RefCounted`) lo necesita, **y todas las clases de una jerarquía de herencia y todos los `partial` de archivos múltiples**.
- `GD0002` → la clase contenedora de una clase Godot anidada también debe ser `partial`.
- **Niche (GH-104268):** una clase Godot **anidada dentro de una clase genérica** históricamente rompía los source generators con errores crípticos aunque pusieras `partial` en todo (corregido en PR #104279, milestone 4.5, así que en 4.6.x ya va bien). Si lo ves en una versión vieja, el desatasque es sacar la clase al namespace de nivel superior.
- **`SignalName.X` marcado como `CS0246` por el IDE pero compila** → el generador emite el miembro y el language server (OmniSharp/Rider) está desincronizado. Fix: `dotnet build` desde terminal, reinicia el servidor de lenguaje, borra `obj/`+`bin/`. NO recurras al string mágico para "callarlo". (GH-81674, GH-82268)

**Señales:**
- `GD0201: The name of the delegate must end with 'EventHandler'` → `delegate void DiedEventHandler(...)`.
- `GD0202: The parameter of the delegate signature of the signal is not supported` → un parámetro no es Variant-compatible (`List<int>`, POCO custom, `System.Action`). Cámbialo a tipo Variant o hazlo derivar de `Resource`/`GodotObject`.
- `GD0203` → el delegate de señal debe retornar `void`.
- **(GH-82268)** emitir una señal definida en OTRA instancia desde fuera con el helper tipado no se puede directamente; llama a un método de esa instancia que emita la suya.

**Marshalling / colecciones / genéricos:**
- `GD0102: The type of the exported member is not supported` → no puedes exportar `System.Collections.Generic.List<T>` (GH-70298), ni arrays de `Vector2I/3I/4I` (GH-95358), ni arrays de enums (GH-95813). Usa `Godot.Collections.Array<T>`.
- `GD0301: The generic type argument must be a Variant compatible type` y `GD0302: The generic type parameter 'T' must be annotated with the '[MustBeVariant]' attribute` → en métodos genéricos que tocan Variant: `void Foo<[MustBeVariant] T>(T v)`.
- **Niche (GH-91345):** `CSC : warning AD0001: Analyzer 'Godot.SourceGenerators.MustBeVariantAnalyzer' threw an exception` → suele venir de usar `dynamic` o patrones genéricos que el analizador no maneja. Evita `dynamic` en superficies que tocan Variant; usa tipos concretos o `Variant.From<T>()`/`.As<T>()`.
- **Trampa de copia (GH-42484):** leer un valor-tipo de un `Godot.Collections.Dictionary` puede devolver una **copia**; mutarla no afecta al diccionario. Lee, muta, **reescribe**: `dict[key] = modified`.
- **Verificar, no asumir:** circula un reporte de `[Export] Array` que aparece **vacío en el build exportado** por trimming/stripping agresivo. No está confirmado como bug general de 4.6.3; trátalo como check: valida exports/colecciones en un **build exportado real**, no solo en editor.

**Ciclo de vida (compila perfecto, crashea en runtime — el más insidioso):**
- `System.ObjectDisposedException: Cannot access a disposed object. Object name: 'Godot.Node3D'.` → guardaste una ref C# a un `Node` que se liberó (`QueueFree`/cambio de escena/padre destruido). **`IsInstanceValid` es la única forma correcta de chequear vida; NO compares contra `null`** (la ref managed puede seguir no-null sobre un objeto nativo muerto). Patrón:
  ```csharp
  if (GodotObject.IsInstanceValid(_target) && !_target.IsQueuedForDeletion())
      _target.GlobalPosition = pos;
  ```
- **`Dispose()` ≠ `Free()`:** `Dispose()` suelta solo el handle managed, no destruye el objeto nativo, y sobre un `Node`/`TreeItem` puede causar leaks o dobles liberaciones. Usa `QueueFree()`/`Free()` para nodos; nunca `Dispose()` manual de nodos. (GH-86926, GH-107579; fix RefCounted GH/PR-101006)
- **Niche (GH-89105):** `IsInstanceValid` no rastrea bien la disposición cuando se llama dentro de un `CallDeferred` disparado desde código async/multihilo: puede devolver `true` y aun así lanzar. Marshalla todo el toque de nodos al hilo principal con `CallDeferred`/`Callable.From(...).CallDeferred()` y **revalida dentro** del deferred.

**async/await:**
- `ToSignal(source, signal)` devuelve un `SignalAwaiter` (no un `Task`); se usa con `await` pero no compone directo con `Task.WhenAll`. Espera frame: `await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);`. Espera timer: `await ToSignal(GetTree().CreateTimer(1.5f), SceneTreeTimer.SignalName.Timeout);`.
- **El disposed mid-await:** tras un `await` el nodo pudo morir. Revalida `IsInstanceValid(this)` tras CADA await, o usa un `CancellationTokenSource` cancelado en `_ExitTree()`. `ToSignal` aún no acepta `CancellationToken` nativo (proposals GH-11909 / discussion GH-7993).
- No mezcles `Task.Delay` (hilo del threadpool) con toques a nodos sin volver al hilo principal; `ToSignal` ya resuelve en el hilo del engine.
- **(GH-93608)** una corrutina async puede correr un frame más tras `QueueFree`; no asumas corte inmediato.

**NativeAOT / móvil:**
- Desktop: `<TargetFramework>net8.0</TargetFramework>` + `<PublishAOT>true</PublishAOT>`. Android/iOS: **experimental**; iOS solo exporta desde **macOS + Xcode**, simulador x64; **no cross-OS compile**.
- Trimming rompe rutas de reflexión que Godot usa: corre en editor, crashea al cargar tipos en el build AOT. Añade `TrimmerRootAssembly` para `GodotSharp` y tu assembly.
- **(GH-102747)** el publish AOT falla con **espacios en el nombre del proyecto**. Renombra sin espacios.
- **Web no se salva con AOT: C# sigue sin web en 4.6.**

### Cómo no quedarte atascado (pasos de decisión, en orden de fallo real)

1. **¿Web en el roadmap?** Sí → C# queda casi descartado para el core jugable; usa GDScript. No → sigue.
2. **¿Editor build ".NET/Mono"? ¿`net8.0` en el `.csproj`? ¿`dotnet 8` en el PATH de la sesión GUI?** Si el build no resuelve `Godot.NET.Sdk`, esto es lo primero.
3. **¿Toda clase Godot es `partial`** (y sus contenedoras)? GD0001/GD0002.
4. **¿Lo que cruza al engine** (señales, `[Export]`, genéricos) es **Variant-compatible**? `Godot.Collections.*` en fronteras, `System.Collections.*` solo interno. `[MustBeVariant]` en genéricos. GD0102/GD0202/GD0301/GD0302.
5. **¿`IsInstanceValid` (+ `IsQueuedForDeletion`)** antes de tocar refs cacheadas, tras cada `await`, y **dentro** de deferreds? `QueueFree`, nunca `Dispose()` manual de nodos.
6. **¿`SignalName.X` da CS0246 fantasma?** Rebuild + reset language server, no string-magic.
7. **¿AOT/móvil?** root assemblies, sin espacios en el nombre, target net8, experimental.

### Addon vs construirlo

- **No necesitas addon** para lo canónico: source generators (`[Export]`, `[Signal]`, `SignalName`/`MethodName`/`PropertyName`, helpers `EmitSignalXxx`) y los analizadores GDxxxx **vienen dentro de `Godot.NET.Sdk`**.
- **Opcional, reduce boilerplate de `GetNode`:** `GodotSharp.SourceGenerators` (Cat-Lips) o `godot-tscn-source-generator` (estilo `@onready`). No imprescindibles.
- **Opcional, async serio:** `GDTask` (Fractural, port de UniTask) para `GDTask`, delays sin alocar y cancelación integrada en cinemáticas/secuencias de combate encadenadas. Para 2-3 awaits sueltos, `ToSignal` + `CancellationTokenSource` es suficiente — no metas la dependencia.

**Veredicto ponytail:** el mejor código C# en Godot 4.6 es el que NO escribes: deja que Godot genere el `.csproj`, que los source generators generen señales/exports, que `Resource`/`RefCounted` se autogestionen por refcount, y que `ToSignal` cubra el async simple. El código que SÍ debes escribir es el "core" CPU-intensivo (stats, IA, saves) que justifica salir de GDScript. Y memoriza tres reflejos: `partial` en toda clase Godot, `Godot.Collections.*` en las fronteras del engine, e `IsInstanceValid` antes de tocar cualquier ref que pudo morir. Esos tres reflejos evitan el 90% de los atascos.

## 16. Auto-verificación headless, CLI y testing

> **Para una IA que NO ve el editor.** El objetivo de este tema es cerrar el lazo **edito → compruebo → corrijo** sin ventana. La pieza central es `godot --headless` + **parseo de stdout/stderr** (no del exit code en la mayoría de los pasos). Versión de referencia: Godot 4.6.x (release 2026-01-27).

### Enfoque nativo recomendado

Pipeline obligatorio de 4 fases, de la más barata a la más cara. **No te saltes la Fase 0**: es la causa #1 de atascos.

```
0. --import --quit-after 2     → puebla .godot/ (caché de import, class_name, uid://)
1. --check-only / tool propio  → parseo de GDScript (fail-fast barato)
2. --headless --quit-after N   → smoke test: ¿arranca el MainLoop de verdad?
3. GUT / gdUnit4               → tests con exit code FIABLE
(4. --export-* )               → el último, el más frágil
```

**Regla de oro:** B, C y 4 dependen de que A haya poblado `.godot/`. La carpeta `.godot/` está en `.gitignore` por defecto, así que **en cualquier checkout limpio (lo que ve la IA al clonar) no existe**. Los errores de "recurso no importado" / "Could not find base class" / "Unrecognized UID" tras un clon limpio son **caché, no código**: no edites el script, reimporta.

#### CLI exacto de Godot 4.6 (flags verificados)

| Flag | Comportamiento |
|---|---|
| `--headless` | Sin ventana/GPU; implica driver dummy de video y audio. Obligatorio en CI. |
| `--path <dir>` | Directorio del proyecto (donde está `project.godot`). |
| `--import` | Reimporta assets y recrea `.godot/imported`, registra `class_name`/`uid://`. |
| `--quit-after <N>` | Sale tras **N** frames. Usa **2** para import (ver pitfall). |
| `--quit` | Sale tras el primer frame idle. **Evítalo para import** (ver pitfall). |
| `--check-only` | Carga y parsea el script y cierra (no ejecuta). Se usa con `--script`. |
| `-s, --script <res://...>` | Ejecuta un script (`SceneTree`/`MainLoop`/`EditorScript`). |
| `-e, --editor` | Modo editor (necesario para `EditorScript`/`EditorInterface`). |
| `--export-release <preset> <out>` / `--export-debug <preset> <out>` | Exporta con preset de `export_presets.cfg`. |
| `--verbose` (`-v`) | Salida detallada; útil para ver qué recurso falla. |
| `--doctool [path]` | Vuelca el XML de doc de clases (verificar APIs disponibles). |

Doc oficial: `https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html`

### Fase 0 — Warm-up de imports

```bash
# Puebla .godot/ : reimporta assets, registra class_name y uid://.
# NUNCA uses --quit aquí; usa --quit-after 2 (un frame importa, el segundo asienta dependencias).
godot --headless --path . --import --quit-after 2 --verbose
# Si persisten warnings de uid://, una SEGUNDA pasada los resuelve:
godot --headless --path . --import --quit-after 2
```

Algunas builds 4.x salen solas con un `--import` "pelado" y bastan; pero `--quit-after 2` es el patrón seguro y portable que no se cuelga ni sale antes de tiempo (GH-77508). Para proyectos migrados desde <4.4: corre **Project > Tools > Upgrade Project Files** una vez en el editor (o `godot --headless --editor --path . --quit-after 2`) para generar los `.uid`. 4.6 ya no escribe `load_steps` en los `.tscn`; no lo edites a mano.

### Fase 1 — Validación de sintaxis

Dos rutas. La primera es trivial; la segunda es **más fiable** y la recomendada para un agente.

```bash
# Ruta A: built-in, un archivo. ¡OJO con el exit code (ver pitfalls)! Decide por TEXTO:
out=$(godot --headless --path . --check-only --script res://scripts/player.gd 2>&1)
echo "$out"
if echo "$out" | grep -qiE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'; then
  echo "FAIL: parse error"; exit 1
fi
echo "OK"
```

```bash
# Ruta B (RECOMENDADA): tool script propio que valida TODOS los .gd y controla su PROPIO exit code.
godot --headless --path . --script res://ci/validate_all.gd
echo "exit=$?"   # FIABLE: lo fijamos nosotros con quit(N)
```

La Ruta B esquiva el bug histórico del exit code de `--check-only` porque **tú** controlas `quit(N)`. Ver `examples/validate_all.gd`.

### Fase 2 — Smoke test (¿ARRANCA, no solo compila?)

Compilar no es arrancar: un autoload que peta en `_ready()`, una escena principal con un nodo nulo, etc., solo se ven booteando.

```bash
# Arranca el juego real (autoloads + escena principal), corre N frames y sale.
# timeout + </dev/null son OBLIGATORIOS (ver pitfall del debugger invisible).
out=$(timeout 120 godot --headless --path . --quit-after 90 </dev/null 2>&1)
rc=$?
echo "$out"
if [ "$rc" = "124" ]; then echo "BOOT HANG (timeout)"; exit 1; fi
if echo "$out" | grep -qiE 'SCRIPT ERROR|Cannot call method|Nonexistent function|Invalid (get|set|call)|^ERROR:'; then
  echo "BOOT FAILED"; exit 1
fi
echo "BOOT OK"
```

### Fase 3 — Testing (exit code fiable)

| | **GUT** | **gdUnit4** |
|---|---|---|
| Lenguaje | GDScript | GDScript **+ C#/.NET 8** |
| Runner CLI | `-s res://addons/gut/gut_cmdln.gd ... -gexit` | `addons/gdUnit4/runtest.sh` |
| Exit code | 0 pasan / 1 falla (con `-gexit`) | 0/1 (JUnit XML + HTML) |
| Mocking/scene runner | básico | mocking, spies, fuzzing, scene runner |
| GitHub Action oficial | no | `gdunit4-action` |
| Code coverage | sí (addon comunitario) | no nativo |

```bash
# GUT (GDScript). Exit code FIABLE con -gexit.
timeout 300 godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit </dev/null
echo "exit=$?"   # 0 = todos pasan, 1 = algún fallo
```

```bash
# gdUnit4 (GDScript o C#). --ignoreHeadlessMode es OBLIGATORIO en headless.
export GODOT_BIN=/usr/local/bin/godot
chmod +x ./addons/gdUnit4/runtest.sh
./addons/gdUnit4/runtest.sh -a res://test --ignoreHeadlessMode --continue
```

**Recomendación:** GDScript puro + quieres coverage → **GUT**. Mezclas C# (.NET 8) o quieres scene runner/mocks + Action oficial → **gdUnit4**. **No mezcles los dos** en el mismo repo. En todos los casos exporta `GODOT_DISABLE_LEAK_CHECKS=1` para que los "ObjectDB instances leaked" no contaminen el exit code (libera igual tus objetos con `free()`/`autofree()`).

### Pitfalls y mensajes de error literales

**P1 — El exit code de `--check-only` MIENTE (el peor para una IA).** Históricamente devolvió siempre **0** con error de parseo (GH-33895), luego siempre **1** con script válido (GH-54087), y daba falsos positivos por chequear el script antes de registrar los autoloads (GH-78587), corregido por PR #110295. El bug genérico de no propagar exit no-cero está en GH-85062. Aun así no confíes en `$?` de `--check-only`.
→ **Fix:** no uses `$?` con `--check-only`. **Grepea `SCRIPT ERROR` / `Parse Error` en stdout/stderr**, o usa el tool script propio con `quit(N)`. El error literal sí es fiable y trae archivo:línea:
```
SCRIPT ERROR: Parse Error: Identifier "helth" not declared in the current scope.
          at: GDScript::reload (res://scripts/player.gd:42)
```
La IA usa ese `res://...:LINEA` para auto-corregir.

**P2 — Checkout limpio sin `.godot/` → "errores de código" que no lo son.** Mensajes literales:
```
ERROR: Failed loading resource: res://.godot/imported/icon.svg-<hash>.ctex.
       Make sure resources have been imported by opening the project in the editor at least once.
SCRIPT ERROR: Parse Error: Could not find base class "MyBaseClass".
WARNING: Unrecognized UID: "uid://abc123" — using text path instead.
```
→ **Fix:** Fase 0 (`--import --quit-after 2`), a veces **doble pasada**. (GH-71521, GH-93424, GH-115205; UID changes article.)

**P3 — El DEBUGGER INTERACTIVO INVISIBLE cuelga el CI para siempre.** Ante un error de runtime (o incluso sintaxis en carga, GH-85699) headless cae a un prompt esperando stdin:
```
Debugger Break, Reason: 'assertion failed'
debug>
```
La IA, que no ve nada, espera output que nunca llega.
→ **Fix:** SIEMPRE `--quit-after N` + `timeout 120 ...` + `</dev/null`. No es opcional. (GH-51387, GH-42465.)

**P4 — `--import --quit` / `--quit-after 1` salen ANTES de importar, o devuelven exit 1 espurio.** (GH-77508, GH-83449.)
→ **Fix:** usa `--quit-after 2`; en el paso de import **no juzgues por exit code**, verifica por log.

**P5 — Tool scripts con clases de editor revientan headless.** `@tool` que usa `EditorInterface`/`EditorPlugin` en runtime falla con parse error (GH-91713).
→ **Fix:** envuelve esas llamadas en `if Engine.is_editor_hint():` y nunca las invoques en runtime headless.

**P6 — `--check-only` NO muestra warnings.** Solo errores; los warnings del editor (typed dicts mal usados, narrowing) requieren LSP/editor (forum 124343/132160).
→ **Fix:** configura `[debug] gdscript/warnings/...` como errores en `project.godot` y trátalos en tests.

**P7 — Export "verde" con binario roto.** `--export-release` no siempre propaga exit no-cero (GH-83042/85062); se congela si falta `.godot/` (GH-95287, GH-71521); faltan templates:
```
No export template found at the expected path .../export_templates/4.6.stable/...
```
→ **Fix:** importa primero; verifica que el artefacto existe y pesa >0 (`test -s out`) + grep `ERROR` en el log. Templates en `~/.local/share/godot/export_templates/4.6.stable/` o usa imagen `barichello/godot-ci`. C# **NO** exporta a web (web = Compatibility, sin .NET).

**P8 — GUT/gdUnit4 "no encuentra tests" o exit 0 falso.** Falta `-gexit` (GUT) o `--ignoreHeadlessMode` (gdUnit4). GUT desalineado da `Invalid call. Nonexistent function ... GutRunner.gd:112` (GH-Gut 491). gdUnit4 desalineado: `Could not find type GdUnitHtmlReport` (GD-345) / load error en CI (GD-487).
→ **Fix:** añade el flag correcto; alinea la versión del addon con Godot 4.6; haz Fase 0 antes.

### Cómo no quedarte atascado

El bucle de auto-corrección de la IA es:
```
import (--quit-after 2)
  → validate_all.gd (exit code propio FIABLE)
  → leer "res://archivo.gd:LINEA" del SCRIPT ERROR
  → editar esa línea
  → re-validar
  → smoke (--quit-after 90, con timeout + </dev/null)
  → tests (GUT -gexit / gdUnit4 --ignoreHeadlessMode)
```
Tres mandamientos: **(1)** import primero, siempre; **(2)** la verdad está en stdout/stderr, no en `$?`, salvo en GUT/gdUnit4; **(3)** nunca lances headless sin `timeout ... </dev/null`.

### Addon vs construirlo

- **Validación de parseo: built-in + 20 líneas propias.** `--check-only` ya está en el engine; el tool script `validate_all.gd` (que controla su exit code) es más fiable que `--check-only` y trivial de construir → **construir gana aquí**.
- **Testing: usa addon, NO construyas.** GUT o gdUnit4 resuelven exit codes, mocking y scene runner; reinventar un runner es regalar bugs.

**Veredicto ponytail:** el mejor código aquí es el que no escribes en el runner de tests (GUT/gdUnit4 ya existen y dan el único exit code fiable), pero **sí** escribes el tool script de validación de 20 líneas: es más barato y más fiable que pelearte con un exit code de `--check-only` que lleva años mintiendo. Importa primero, lee el texto (no `$?`), y blinda cada invocación con `timeout`+`</dev/null` para no morir en un debugger que no puedes ver.

## 17. Formatos .tscn/.tres/project.godot y UIDs

Estos archivos son texto tipo INI que el editor de Godot trata como **fuente de verdad regenerable**. Una IA que NO ve el editor puede generarlos y editarlos a mano, pero el parser es **estricto y de una sola pasada**: orden de secciones, IDs string entre comillas, formato de tipos y referencias deben ser exactos. El campo de minas #1 son los **UIDs**: inventarlos produce warnings y refs frágiles. La regla de oro: genera el contenido determinista a mano, pero **deja que Godot asigne/repare los UIDs** (re-guardado en editor o `--headless --import`).

### Enfoque nativo recomendado

No necesitas ningún addon para generar `.tscn`/`.tres`/`project.godot`: son texto, y para crear recursos por código los singletons del core (`ResourceSaver`, `ResourceUID`, `ResourceLoader`) bastan. El "addon canónico" para regenerar UIDs y cache es el propio engine vía `godot --headless --import`.

**Lo que cambió en 4.6 (verificado en la guía oficial de upgrade):**

1. **`load_steps` se eliminó del header.** En 4.6 el engine ya **no escribe** `load_steps` al guardar (seguía siendo solo para la barra de progreso, y ensuciaba diffs/rebases en VCS). Sigue parseándolo si está presente por compatibilidad, pero lo borra al re-guardar. **Una IA generando escenas 4.6 NO debe escribir `load_steps`.** Es el primer red flag que delata texto generado con docs viejos.
2. **Cada nodo guarda un identificador entero estable** (atributo `unique_id=NNNN` en el `[node]`, p.ej. `[node name="Ball" ... unique_id=1358867382]`), distinto de los `uid://` de escena/recurso, para sobrevivir a renombrados/movimientos en herencia de escenas (refactor más robusto). Es retro/forward-compatible (escenas 4.5 cargan en 4.6 y viceversa). No lo escribas a mano ni emitas un `uid://` en un nodo; el editor lo añade solo al re-guardar.
3. **`load_steps` + `unique_id` de nodo = diff masivo** la primera vez que abres+guardas un proyecto 4.5 en 4.6. Hazlo en un commit aislado tras `Project > Tools > Upgrade Project Files...`.

**Header canónico 4.6 (sin `load_steps`):**

```ini
[gd_scene format=3 uid="uid://cecaux1sm7mo0"]
```
```ini
[gd_resource type="Resource" script_class="ItemData" format=3 uid="uid://b3qf7x2k9m1n0"]
```

`format=3` es obligatorio en 4.x (`format=2` = Godot 3). Ver ejemplos completos abajo.

**Reglas de formato que rompen al editar a mano:**

- **Orden de secciones, no reordenar:** `[gd_scene]` → todos los `[ext_resource]` → todos los `[sub_resource]` (en orden topológico: si uno referencia a otro, va después) → `[node]` → `[connection]` → `[editable]` opcional. Un `[node]` antes de su recurso = parse error de una pasada.
- **IDs son STRING entre comillas** (4.x): `id="2_abc12"`, se referencia con `ExtResource("2_abc12")` / `SubResource("CapsuleShape3D_k3m1")`. Enteros pelados (`id=2`, `ExtResource(2)`) son sintaxis de Godot 3 → corrupción. Cada `id="X"` debe casar EXACTO (comillas incluidas) con cada `ExtResource("X")`/`SubResource("X")`.
- **Paths de nodo relativos al root, SIN el nombre del root.** El root no lleva `parent=`. Hijos directos: `parent="."`. Nietos: `parent="Collision"` (no `parent="Player/Collision"`).
- **`instance=ExtResource(...)` XOR `type="..."`**, nunca ambos en el mismo `[node]`.
- **Literales de tipo:** `Vector3(0, 1, 0)`, `Color(1, 0, 0, 1)`, `Transform3D(...)` = **12 floats** (basis 9 + origen 3, NO 16), `Transform2D` = 6. `NodePath`: `^"Path/Node"`. `StringName`: `&"nombre"`. Typed arrays/dicts: `Array[int]([1, 2, 3])`, `Dictionary[StringName, int]({})`.
- **Propiedades en valor por defecto no se escriben** (el editor las descarta al re-guardar). No luches contra ello.

**UIDs y archivos `.uid` (desde 4.4):**

- Escenas/recursos importados guardan su UID en su propio header (`uid="uid://..."`). **No tienen sidecar.**
- Scripts `.gd` y shaders `.gdshader` son texto plano sin sitio para metadata → reciben un **sidecar `player.gd.uid`** cuyo contenido es una sola línea: `uid://...`.
- El mapa `uid:// → res://ruta` vive en `.godot/uid_cache.bin` (binario, NO se commitea). Por eso un UID inventado a mano que no existe en la cache produce warning hasta el reimport.

**Cargar/resolver por UID (sobrevive a movimientos de fichero):**

```gdscript
var scn := load("uid://cecaux1sm7mo0") as PackedScene   # load() acepta uid:// directo
var id := ResourceUID.text_to_id("uid://cecaux1sm7mo0")
if ResourceUID.has_id(id):
    print(ResourceUID.get_id_path(id))                  # -> res://main.tscn
```

### Pitfalls y mensajes de error literales

- **`ext_resource, invalid UID: uid://<x> - using text path instead`** — El `uid://` no está en `uid_cache.bin` (lo inventaste, borraste `.godot/`, o no commiteaste el `.uid`). NO es error duro: el `path=` aún resuelve y solo emite warning. **Fix:** re-guardar la escena en el editor, o `godot --headless --import` para reconstruir la cache, o `Project > Tools > Upgrade Project Files`. Si quieres limpiar a mano, borra el atributo ` uid="..."` roto del `ext_resource` y deja que Godot lo reasigne al guardar.
- **`...invalid UID ... and there's no fallback at set path`** — UID inválido **y** el `path=` también roto (archivo movido). Esto SÍ es error duro: la escena no carga. Restaura el archivo o corrige `path=`.
- **`Parse Error: [ext_resource] referenced non-existent resource` / `Scene file appears to be invalid/corrupt`** — Sección fuera de orden, `id` sin comillas, `format` incorrecto, `ExtResource("X")`/`SubResource("X")` apuntando a un `id` no declarado, `parent=` a nodo inexistente, o literal mal formado (`Transform3D` con nº de floats incorrecto). **Fix:** grep de cada `id="..."` contra cada referencia; verificar 12 floats en `Transform3D`.
- **Autoload "existe pero no carga":** omitir el prefijo `*` en `[autoload]` → singleton deshabilitado → `Identifier "GameState" not declared`. El valor debe ser `Nombre="*res://..."`.
- **`[input]` editado a mano:** los `InputEvent` se serializan como `Object(InputEventKey, "physical_keycode":4194309, ...)` con decenas de campos y keycodes físicos vs lógicos. Extremadamente frágil. **No lo edites a mano**; usa el editor o `InputMap.add_action()` por código en un autoload.
- **`Invalid type in property` al cargar (4.6 específico):** las props de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`) pasaron de `String` a `StringName` (GH-110767). En `.tscn` usa `current_animation = &"walk"`. NO afecta a nombres de track.
- **`ResourceSaver.save` falla con `ERR_CANT_OPEN`:** la carpeta `res://` destino no existe (Godot NO crea dirs). Llama `DirAccess.make_dir_recursive_absolute()` primero. SIEMPRE comprueba `err == OK`.
- **`ResourceUID.get_id_path()` devuelve inválido/-1 en proyecto EXPORTADO** (godot#75617). No dependas de resolver UID→path en runtime empaquetado. `load("uid://...")` suele funcionar empaquetado porque `uid_cache.bin` se incluye en el PCK, pero hay casos de fallo en export/PCK montados (godot#79009, godot#82061: el `uid_cache.bin` de PCKs montados no se fusiona); si exportas y el UID no resuelve, ten un fallback a `res://` o reconstruye la cache. Lo que NO es fiable en export es resolver UID→path con `get_id_path()`.
- **C# NO corre en export web** (renderer Compatibility). Si el target incluye web, escribe el save/load en GDScript.
- **Duplicate UID** (copy-paste de archivos fuera del editor): dos recursos con el mismo `uid://`. No hay autofix; borra el `.uid` de uno y re-guarda, o `ResourceUID.create_id()`.

### Cómo no quedarte atascado

Flujo headless para una IA ciega tras generar/editar archivos:

```bash
# 1. Validar SINTAXIS de un script (NO valida .tscn/.tres)
godot --headless --check-only --script res://src/player.gd

# 2. Reconstruir uid_cache.bin + reimportar (tras clone, mover archivos o UIDs inventados)
godot --headless --import

# 3. Cargar escenas y cazar errores de parseo en el log
godot --headless --quit-after 2 --verbose 2>&1 | grep -iE "error|invalid uid|parse"
```

- **`--check-only` solo valida GDScript, NO escenas.** Las escenas solo se validan al cargarlas: arranca headless y parsea el stderr.
- **Pitfall CI muy documentado:** con `.godot/` ignorado, en un clone fresco los recursos no están importados → `--export-release` falla. El workaround `--headless --editor --quit` NO es fiable. Usa **`--quit-after 2`** (con `--quit` o `--quit-after 1` el import no termina, issue #77508). Corre un paso `--headless --import` dedicado ANTES de exportar.
- **Mover archivos fuera del editor:** mueve SIEMPRE el `.uid` (y el `.import` del asset) junto al archivo. `git mv player.gd nueva/player.gd && git mv player.gd.uid nueva/player.gd.uid`. Olvidar el `.uid` regenera un UID nuevo → todas las refs por UID viejo rotas.
- **VCS:** ignora **toda** la carpeta `.godot/`. **COMMITEA** los `*.uid` (son estado del proyecto, no output; ignorarlos rompe los enlaces escena↔script para todo colaborador) y los `*.import` de assets (contienen el UID estable del asset). `.gitignore` 4.x oficial = básicamente solo `.godot/`. Genera metadata con `Project > Version Control > Generate Version Control Metadata`.

### Addon vs construirlo

- **Generar `.tscn`/`.tres`/`project.godot` a mano: construir.** Es texto determinista; la skill es justamente esto. Pero omite `uid://` inventados y valida con arranque headless.
- **InputMap en `project.godot`: NO a mano.** Usa `InputMap.add_action()` por código o el editor.
- **Regenerar UIDs/cache: usa el engine** (`--headless --import`), no reinventes el parser.
- **Cargar `.tres` desde savegames NO confiables del jugador: usa addon.** `ResourceLoader.load()` ejecuta scripts/sub-recursos embebidos → vector de RCE. Para datos no confiables usa [godot-safe-resource-loader](https://github.com/derkork/godot-safe-resource-loader). Para data interna definida por ti, `ResourceLoader` normal está bien.

**Veredicto ponytail:** el mejor `.tscn` es el que no escribes a mano. Genera por código con `ResourceSaver.save()` (que asigna y persiste el UID por ti) o deja que el editor sea la fuente de verdad; reserva la edición a mano para cambios deterministas (cabeceras, nodos, autoloads) y nunca inventes un `uid://`. Cuando dudes, `godot --headless --import` y parsea el log: es la red de seguridad que evita el atasco.

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

## 19. Audio: música, SFX y buses

Godot 4.6 (lanzado 2026-01-27, rama ~4.6.x) trae un sistema de audio completo: nada de lo que un RPG open-source necesita (música persistente, pool de SFX, ducking, capas adaptativas) requiere middleware externo. El enrutado es siempre el mismo: **`AudioStreamPlayer*` → bus (por nombre) → cadena de `AudioEffect` → bus padre → … → `Master` → salida**.

### Enfoque nativo recomendado

| Necesidad | Clase / API 4.6 | Tipo |
|---|---|---|
| Música global / UI / 2D no espacial | `AudioStreamPlayer` | Node |
| SFX posicional 3D (RPG) | `AudioStreamPlayer3D` | Node |
| SFX posicional 2D | `AudioStreamPlayer2D` | Node |
| Volumen por categoría / mezcla | Audio Buses + `AudioServer` (singleton) | API |
| Pool de SFX en un solo nodo | `AudioStreamPolyphonic` + `AudioStreamPlaybackPolyphonic` | Resource |
| Música adaptativa por estado (combate↔exploración) | `AudioStreamInteractive` | Resource |
| Playlist secuencial/aleatoria con crossfade | `AudioStreamPlaylist` | Resource |
| Capas sincronizadas (stems) | `AudioStreamSynchronized` | Resource |
| Layout de buses persistido | `AudioBusLayout` (`.tres`) | Resource |

`AudioStreamInteractive/Playlist/Synchronized` viven en el módulo `interactive_music` (presente en builds oficiales desde 4.3). **Son Resources, no Nodes**: se asignan a `player.stream`, NUNCA `add_child(AudioStreamInteractive.new())`.

Arquitectura RPG canónica:
- **Música = autoload con `AudioStreamPlayer`** (sobrevive a `change_scene_to_*`).
- **SFX 3D del mundo = nodos `AudioStreamPlayer3D`** colgando del emisor (mueren con la escena, que es lo correcto).
- **SFX globales/UI = autoload con `AudioStreamPolyphonic`** (un nodo, N voces, sin instanciar nodos por disparo).
- **Buses sugeridos:** `Master → Music`, `Master → SFX`, `Master → UI`, `Master → Ambient`, `Master → Voice`.

#### El modelo de volumen: dB, no lineal (EL pitfall número uno)

`volume_db` y `AudioServer.set_bus_volume_db()` están en **decibelios**, no en [0,1]. `volume_db = 0.0` es ganancia unidad (sin cambio), `-80.0` es silencio efectivo. Conectar un slider lineal [0,1] directo a `volume_db` da basura: `volume_db = 0.5` es +0.5 dB (casi imperceptible), NO "mitad de volumen". Convierte con `linear_to_db()` / `db_to_linear()` (globales de `@GlobalScope`).

En 4.6 existen alternativas lineales verificadas que evitan toda la conversión manual:
- `AudioStreamPlayer*.volume_linear` (propiedad 0..1; Godot la convierte a `volume_db` internamente).
- `AudioServer.set_bus_volume_linear(idx, linear)` / `get_bus_volume_linear(idx)`.

Para una IA que quiera blindar el código, `volume_linear` y `set_bus_volume_linear` son la ruta menos propensa a errores. Si usas dB: piso de silencio en **-80**, NUNCA `linear_to_db(0.0)` (devuelve `-inf` → al tweenear produce `NaN` y silencio permanente).

#### Buses: direccionamiento mixto y fallback silencioso

El nodo direcciona por nombre (`bus: StringName`, def `&"Master"`); la API de servidor usa índice: `AudioServer.get_bus_index("Music")` devuelve **-1** si no existe. **Pitfall crítico y silencioso (verificado en docs):** asignar `player.bus = "Music"` cuando el bus no existe NO lanza error — hace fallback a `"Master"`. Síntoma típico para una IA ciega: "el slider de música también baja los SFX" (ambos cayeron a Master). Sonda diagnóstica:

```gdscript
assert(AudioServer.get_bus_index("Music") != -1, "Bus 'Music' inexistente -> fallback silencioso a Master")
```

El layout es un `AudioBusLayout.tres`, ruta en `project.godot` bajo `[audio] buses/default_bus_layout`. **El `.tres` gana al arrancar**: si creas buses por código y además hay un `.tres`, el archivo manda. Para persistir buses creados por código: `AudioServer.generate_bus_layout()` → `ResourceSaver.save(layout, "res://default_bus_layout.tres")`. En 4.6 los `.tres`/`.tscn` ya **no escriben `load_steps`** y los recursos usan `uid://` + ficheros `.uid` (desde 4.4); tras tocar archivos a mano corre **Project → Tools → Upgrade Project Files** o `godot --headless --import`.

#### SFX: polifonía vs pool

Por defecto `AudioStreamPlayer*.max_polyphony = 1`: un segundo `play()` **corta** el anterior. Dos enfoques para solapar:

- **Solapar UN tipo de sonido (pasos):** sube `max_polyphony` (p.ej. 8) en un solo player. Lo más simple.
- **Pool real con control individual:** `AudioStreamPolyphonic` como `stream`; `play_stream()` devuelve un ID por voz, y controlas `set_stream_volume(id, db)` / `stop_stream(id)`. `play_stream` devuelve `INVALID_ID` si se alcanzó `polyphony` (def 32).

**Cuándo NO usar el polifónico:** si tu lógica necesita "avísame cuando ESTE disparo terminó", `AudioStreamPlaybackPolyphonic` **no emite `finished` por stream** (issue abierto GH-88941). En ese caso usa un pool de `AudioStreamPlayer` reusados (cada uno emite su `finished`). El pool de nodos reusados también evita el churn de `new()`+`add_child()`+`queue_free()` por golpe, que causa stutter con muchas entidades.

#### Música adaptativa / crossfade

- `AudioStreamPlaylist`: clips secuenciales/aleatorios con `fade_time` (crossfade integrado, def 0.3s). Lo más simple para ambiente que rota.
- `AudioStreamInteractive`: tabla de transiciones (immediate / end-of-clip / beat boundary) entre clips por estado. Disparo por código: `player.get_stream_playback().switch_to_clip_by_name(&"Combat")`. La tabla se construye en el editor.
- `AudioStreamSynchronized`: capas (stems) en sync; subes/bajas volumen por capa con `set_sync_stream_volume(idx, db)`.

Para un crossfade simple de 2 temas (lo habitual en un RPG), **no necesitas estas clases ni un addon**: dos `AudioStreamPlayer` + un `Tween` sobre `volume_db` bastan (ver ejemplo). Reserva `AudioStreamInteractive` para cuando el compositor entregue la transition table hecha; anidar `Interactive`+`Synchronized` es frágil y poco documentado (las transiciones por beat se desincronizan si las capas difieren en longitud).

#### Ducking

- **Manual con Tween (recomendado, predecible):** al iniciar diálogo, `Tween` sobre `volume_db` del bus Music a -12 dB; al terminar, vuelve a 0.
- **Sidechain con `AudioEffectCompressor`:** propiedad `sidechain` (verificada como `StringName` = nombre del bus fuente). El compressor baja Music según el nivel de Voice. CAVEAT (GH-16036): el routing del sidechain históricamente tuvo bugs; verifica que el bus fuente exista y NO se envíe a sí mismo. Por eso el Tween manual es la opción "que no se atasca".

#### AudioStreamPlayer3D: atenuación y zonas acústicas

- `attenuation_model`: `INVERSE_DISTANCE` (def) / `INVERSE_SQUARE_DISTANCE` / `LOGARITHMIC` / `DISABLED`.
- `unit_size` (def 10.0): controla la curva de atenuación — el parámetro que la gente no toca ("se oye igual en todo el mapa" o "no se oye nada").
- `max_distance` (def 0.0 = sin límite, audible siempre): corta a cero y, clave para rendimiento, deja de mezclar lejos.
- **Zonas acústicas sin código:** un `Area3D` con `audio_bus_override = true` + `audio_bus_name = "Cave"` redirige todo `AudioStreamPlayer3D` cuyo `area_mask` case con la capa del área (cueva → bus con reverb; agua → bus con `AudioEffectLowPassFilter`). Idiomático.

**Pitfall confusión:** `unit_size` ≠ `max_distance`. Subir `unit_size` hace que llegue más lejos; `max_distance = 0` significa "infinito", no "cero alcance".

### Pitfalls y mensajes de error literales

- **`Condition "p_bus < 0 || p_bus >= buses.size()" is true.`** → pasaste `idx = -1` (de `get_bus_index` con nombre mal escrito) a `set_bus_volume_db`. Fix: chequear `!= -1`. Nombres case-sensitive.
- **`Attempt to call function 'play_stream' in base 'null instance'`** / C# `NullReferenceException` en `GetStreamPlayback` → llamaste `get_stream_playback()` antes de asignar un `AudioStreamPolyphonic` como `stream` y/o antes de `play()`. Fix: asigna stream → `add_child` → `play()` → *después* `get_stream_playback()`.
- **`play_stream(...)` devuelve `INVALID_ID` silenciosamente** → se alcanzó `polyphony`. Fix: sube `polyphony`.
- **`'GD' does not contain a definition for 'Linear2Db'`** (C#) → API 3.x. En 4.x usa `Mathf.LinearToDb` / `Mathf.DbToLinear`.
- **C#: el tween "no hace nada"** → usaste `"VolumeDb"` como property path. El path interno del motor es snake_case: `"volume_db"` (aunque la propiedad C# sea `VolumeDb`).
- **Impreso `-inf` + audio mudo permanente / `nan`** → `linear_to_db(0.0)`. Fix: floor en -80 o clamp el lineal a `0.0001`.
- **Sin error, simplemente silencio/reinicio al cambiar de escena** → el player colgaba de la escena liberada. Fix: autoload.
- **"loop=true en código y el OGG igual se corta"** → el loop de OGG/MP3 vive en `archivo.ogg.import`, NO en el recurso (GH-42671): *"the loop property on AudioStreamOggVorbis is only acknowledged by the editor, and the game uses instead the loop option set when importing"*. Fix: ver siguiente sección.
- **`finished → queue_free` y los nodos se acumulan** → clip marcado como loop en import nunca termina, nunca emite `finished` (GH-102479). Fix: no loopear SFX one-shot, o no atar `queue_free` a `finished` de un loop.
- **Audio 3D suena pero "sin dirección / centrado"** → no hay listener. Por defecto la `Camera3D` activa es el listener; si añades un `AudioListener3D` debes llamar `make_current()`.
- **Web export crash (GH-109728):** pausar el árbol con un player en `playback_type = PLAYBACK_TYPE_SAMPLE` reproduciendo `AudioStreamPlaylist/Interactive/Synchronized` crashea en wasm. Fix: en web usa `PLAYBACK_TYPE_STREAM` para esos streams compuestos.

### Cómo no quedarte atascado

Una IA que no ve el editor se clava sobre todo en metadata invisible (loop de import, listener, fallback de bus). Rutas accionables por CLI/código:

1. **Loop de OGG sin editor:** edita el sidecar `res://music/town.ogg.import`, en `[params]` pon `loop=true` y `loop_offset=0.0` (`loop_offset > 0` puede producir un click/pop al loopear — GH-64775; deja `0.0`). Para WAV: `edit/loop_mode=1` (Forward). Reimporta con `godot --headless --import` (editar el `.import` a mano NO reimporta solo).
2. **Loop garantizado 100% por código** (ignora el `.import`): `var s := AudioStreamOggVorbis.load_from_file("res://music/town.ogg"); s.loop = true; s.loop_offset = 0.0; player.stream = s`. La instancia cargada así no está atada al pipeline de import.
3. **Registrar autoload por código** (la IA no puede usar el botón): en `project.godot`, sección `[autoload]`, `MusicManager="*res://autoload/music_manager.gd"`. El `*` = enabled; sin él, stuck silencioso.
4. **Validación headless:** `godot --headless --import` tras tocar `.import`/bus layout; `godot --headless --check-only --script res://autoload/music_manager.gd` para validar sintaxis GDScript.
5. **Mono vs estéreo:** un OGG/WAV estéreo en `AudioStreamPlayer3D` no se panea bien; el audio posicional quiere fuentes **mono**.
6. **Guardas obligatorias:** "misma pista no reinicia" (`if _active.stream == stream and _active.playing: return`), `get_bus_index != -1` antes de usar el índice, piso de -80 dB en fades.

| Síntoma | Sonda por código/CLI | Causa raíz |
|---|---|---|
| Slider de música mueve los SFX | `AudioServer.get_bus_index("Music") == -1` | Bus mal escrito → fallback a Master |
| No se oye nada en 3D | ¿`Camera3D.current` o `AudioListener3D.make_current()`? ¿`unit_size`/`max_distance` sanos? | Sin listener o atenuación mal |
| Música no loopea pese a loop=true | leer/editar `*.ogg.import`; `godot --headless --import` | Loop vive en import (GH-42671) |
| Slider en 0 no silencia / volumen raro | ¿`linear_to_db`/`volume_linear`? ¿clamp? | Confundir dB con lineal |
| C# no compila: Linear2Db | `Mathf.LinearToDb` | API 3.x obsoleta |
| Nodos de SFX se acumulan / FPS cae | ¿clip loop + `finished→queue_free`? | GH-102479 |
| Música se reinicia al cambiar sala | ¿player en autoload? ¿guard misma pista? | Player en escena liberada |

### Addon vs construirlo

**Construir con nativo (sin addon)** cubre el 100% del RPG open-source: MusicManager persistente, pool de SFX, ducking, buses, atenuación 3D, zonas por `Area3D`, y música adaptativa (`AudioStreamInteractive/Playlist/Synchronized`, nativas desde 4.3). Solo considera **FMOD** (`github.com/utopia-rise/fmod-gdextension`) o **Wwise** vía GDExtension si tu equipo de audio YA trabaja en esas herramientas — coste: binarios nativos por plataforma, **no funcionan en export web**, complican CI/CLI. Para open-source casi nunca compensa.

**Veredicto ponytail:** el mejor código de audio es el que no escribes. Reusa `AudioStreamPlayer` + buses por nombre + `volume_linear` (o `linear_to_db`), deja que `Area3D` con `audio_bus_override` haga las zonas acústicas y que `AudioStreamPlaylist`/`Synchronized` hagan el crossfade y las capas. El único código propio que un RPG realmente necesita es el autoload `MusicManager` (porque la persistencia entre escenas no es nativa) y, opcionalmente, un pool de SFX. Todo lo demás ya está en el motor: no metas middleware ni reinventes la mezcla.

## 20. Input a fondo: teclado, ratón y gamepad

Godot 4.6 (estable, ~4.6.3, lanzada 2026-01-27). Las APIs de Input son **estables desde 4.0**: nada de lo de aquí es "nuevo en 4.6". Si una IA te dice que `Input.get_vector` o `InputMap` cambiaron en 4.6, está alucinando — lo único que toca 4.6 (`uid://`, Jolt, D3D12, fin de `load_steps`) no afecta a Input salvo al editar `project.godot` a mano (sección 9).

### Enfoque nativo recomendado

Hay **dos capas** y mezclarlas es el error número uno de una IA que no ve el editor:

| Capa | Qué es | Cómo se consulta | Persistencia |
|---|---|---|---|
| **Acciones** (`InputMap`) | Nombres lógicos (`"move_forward"`, `"attack"`) mapeados a uno o varios `InputEvent` | Polling: `Input.is_action_pressed("attack")` | **NO se auto-guarda.** Se resetea desde `project.godot` en cada arranque |
| **Eventos crudos** (`InputEvent`) | Llegan a `_input`/`_unhandled_input`/`_gui_input` | Inspeccionas el `event` por tipo | n/a |

Regla de oro para un RPG: define las acciones en `project.godot`, consulta movimiento con polling en `_physics_process`, captura one-shots en `_unhandled_input`. **Nunca leas teclas crudas (`KEY_W`) en gameplay**: rompe el remapeo y el gamepad. Usa el `InputMap` nativo — no construyas tu propio sistema de acciones.

**Movimiento analógico (lo correcto para sticks):**

```gdscript
func _physics_process(delta: float) -> void:
    # get_vector aplica deadzone CIRCULAR y limita la longitud a 1. No sumes ejes a mano.
    var input: Vector2 = Input.get_vector(
        &"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
    var dir: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
    velocity.x = dir.x * SPEED
    velocity.z = dir.z * SPEED
    move_and_slide()
```

Firmas exactas (verificadas en `class_input.html` / `class_inputmap.html`):

```gdscript
Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone := -1.0) -> Vector2  # deadzone circular
Input.get_axis(neg, pos) -> float                                          # = strength(pos)-strength(neg)
Input.is_action_just_pressed(action, exact_match := false) -> bool
Input.get_action_strength(action, exact_match := false) -> float           # 0..1 analógico
Input.action_release(action) -> void                                       # libera una acción "pegada"

InputMap.add_action(action: StringName, deadzone := 0.2) -> void           # default 0.2 desde 4.4 (era 0.5 hasta 4.3); el 0.5 solo aplica al toggle-deadzone de las acciones ui_*
InputMap.action_add_event(action, event: InputEvent) -> void
InputMap.action_erase_events(action) -> void                               # borra TODOS (plural)
InputMap.action_erase_event(action, event) -> void                         # borra UNO (singular)
InputMap.action_get_events(action) -> Array[InputEvent]
InputMap.has_action(action) -> bool
InputMap.load_from_project_settings() -> void                              # reset a defaults
```

**One-shots robustos** (atacar, interactuar) van en `_unhandled_input`, **no** con polling:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"attack"):     # método de InputEvent, NO de Input
        _do_attack()
    elif event.is_action_pressed(&"interact"):
        _interact()
```

**Detección teclado↔mando** se infiere del tipo del último `InputEvent` (no existe API "dame el último dispositivo"), filtrando el drift del stick. Ver `examples` para el autoload completo.

**Orden de propagación** (canónico, cada fase recorre el árbol en reverse depth-first):

`_input` → `Control._gui_input` → `_unhandled_key_input` → `_unhandled_input`

- `_input`: casi nunca para gameplay. Solo atajos globales (screenshot, pausa que ignora la UI). Recibe TODO **antes** que la UI.
- `_gui_input`: solo en `Control`, requiere mouse-filter/foco.
- `_unhandled_input`: gameplay del mundo. No se dispara si la UI ya consumió el evento (un click en menú no ataca).

Cortar la cadena: `get_viewport().set_input_as_handled()`. La doc dice "SceneTree.set_input_as_handled" pero el método real está expuesto en **Viewport**; desde un nodo normal usa `get_viewport().set_input_as_handled()`.

**Vibración y multi-gamepad:**

```gdscript
for dev: int in Input.get_connected_joypads():           # Array[int] de device ids
    print(dev, " ", Input.get_joy_name(dev), " guid=", Input.get_joy_guid(dev))

# weak_magnitude, strong_magnitude en 0..1; duration en segundos. duration=0.0 = INFINITO.
Input.start_joy_vibration(0, 0.4, 0.8, 0.3)
Input.stop_joy_vibration(0)

Input.joy_connection_changed.connect(func(device: int, connected: bool) -> void:
    if not connected:
        get_tree().paused = true)
```

### Pitfalls y mensajes de error literales

- **`Request for nonexistent InputMap action 'salto'.`** — La acción no existe en `project.godot` ni se añadió en runtime antes del primer polling, o hay un typo (InputMap es **case-sensitive**: `"Attack"` ≠ `"attack"`). Una acción que existe pero **no tiene eventos** devuelve `false` siempre, **sin error** (la peor variante para una IA ciega). Usa constantes `const ATTACK := &"attack"` y `InputMap.has_action()`.

- **`ERROR: InputMap.add_action: Condition "actions.has(p_action)" is true.`** — Llamaste `add_action` sobre una acción ya existente. Guárdalo con `if not InputMap.has_action(...)`.

- **`keycode` vs `physical_keycode` vs `key_label`** (rompe en AZERTY/QWERTZ y la IA NUNCA lo detecta sin ver el teclado): `keycode` = tecla lógica según layout activo; `physical_keycode` = **posición física** mapeada como QWERTY US (lo que quieres para WASD); `key_label` = etiqueta localizada impresa (solo para mostrar). El error: crear WASD con `keycode = KEY_W` y que un tester AZERTY se queje. Fija `physical_keycode = KEY_W` y deja `keycode = 0`.

- **`as_text_key_label()` devuelve el string literal `(Unset)`** al leer un evento del InputMap en `_ready()`, porque los eventos del proyecto se cargan con `key_label = 0`. Para mostrar la tecla bajo el layout del jugador usa `OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_W))` o `event.as_text_physical_keycode()`. **Bug a tener presente (GH-110751):** `keyboard_get_keycode_from_physical` **devuelve 0 en macOS** — ten un fallback (`OS.get_keycode_string(physical_keycode)`).

- **`is_action_just_pressed` en `_physics_process` descarta inputs (GH-73339).** `just_pressed` compara con el estado del tick anterior; si la acción se pulsa-y-suelta entre dos ticks, el frame se pierde. Síntoma: "el ataque a veces no sale", "el salto se come inputs a bajo FPS". Fix: one-shots en `_unhandled_input` con `event.is_action_pressed`, no en polling. Y mantén cada one-shot en UN solo sitio (no en `_process` y `_physics_process` a la vez → doble salto).

- **`get_vector` no usa la deadzone que crees.** Con el 5º arg en `-1.0` (default) usa el **promedio** de las deadzones de las 4 acciones. Pásala explícita (`0.2`–`0.3`). Mezclar teclado (1.0 binario) y stick analógico en las mismas acciones puede dar saltos cerca de la deadzone (GH-90515, GH-85124). Acción nueva en runtime: el default de `add_action` es **0.2** (desde 4.4; era 0.5 hasta 4.3). Pásalo explícito igualmente para no depender de versiones.

- **`_gui_input` no recibe nada, sin error en consola.** Es `Control.mouse_filter`. Un `Control` base por defecto es `MOUSE_FILTER_IGNORE`; un overlay/`ColorRect` a pantalla completa con `MOUSE_FILTER_STOP` se come todos los clicks y tu `_unhandled_input` nunca los ve. Pon overlays decorativos en `IGNORE` y setea `mouse_filter` explícito en el nodo que debe recibir.

- **Binding "pegado" tras rebindear (GH-63734).** Tras `action_erase_event`, `is_action_pressed` puede seguir `true` si la tecla estaba físicamente pulsada durante el borrado. Fix: `Input.action_release(action)` tras remapear, o ignora el primer frame.

- **Capturar el rebind sin filtrar `echo`/release/drift.** Mantener pulsada la tecla genera auto-repeat (re-bindea en bucle); el drift del stick (`axis_value ~0.05`) se guarda como binding permanente. Filtra: tecla `pressed and not echo`, `JoypadMotion` solo si `absf(axis_value) > 0.5`.

- **`event.device` NO distingue teclado de mando (GH-7161, GH-100491).** Teclado, ratón y el **primer** joypad **todos son `device == 0`** (en project.godot `-1` = "todos los dispositivos"). Discrimina por **tipo de clase** (`event is InputEventKey`), nunca por `device`. Para local co-op, `is_action_pressed` agrega TODOS los mandos → el jugador 2 mueve al jugador 1; hay que duplicar acciones por jugador o leer `_input` crudo filtrando `event.device`.

- **Prompts de UI parpadean teclado↔mando.** Drift del stick emite `InputEventJoypadMotion` constante. Filtra `absf(axis_value) > 0.2` antes de cambiar de esquema. Decisión de diseño: muchos ignoran `InputEventMouseMotion` (rozar el escritorio con mando en mano no debería cambiar a teclado).

- **`start_joy_vibration` no vibra y NO da error.** El código suele estar bien; el problema es dispositivo/SO (GH-94265 Stadia, GH-88674 macOS, GH-73446 Android, DualShock/DualSense por Bluetooth erráticos — prueba USB; Steam Input intercepta el rumble). Trata la vibración como **best-effort**: slider de intensidad + toggle off, nunca mecánicas que dependan de sentirla. `duration=0.0` = vibra infinito hasta `stop_joy_vibration`.

- **`joy_connection_changed` no es fiable** en algunas combinaciones (XInput + Bluetooth, mando conectado tras arrancar en Windows: GH-112802, GH-102942). Re-escanea `get_connected_joypads()` periódicamente además de confiar en la señal.

- **`is_action_pressed` en script `@tool` spamea `Request for nonexistent InputMap action` en el editor** (GH-76566), porque las acciones runtime no existen en contexto de editor. Guarda con `if not Engine.is_editor_hint():` o evita `@tool` en scripts de gameplay.

- **C# (PascalCase):** `InputMap.ActionAddEvent`, `ActionEraseEvents`, `Input.IsActionPressed`, `Input.GetVector`. `InputMap` es estático en C# (no se instancia). `InvalidCastException` si sacas `cfg.GetValue` sin castear a `Godot.Collections.Array<InputEvent>`. **No hay C# en export Web** (Compatibility, sin .NET): si el RPG apunta a web, el menú de rebind debe ser GDScript.

### Cómo no quedarte atascado

Una IA sin editor no puede ver el InputMap. Desatáscate desde terminal:

```bash
# Validar sintaxis de un script de input sin abrir el editor:
godot --headless --check-only --script res://scripts/input_handler.gd

# Arrancar, correr unos frames y volcar logs (verás "Request for nonexistent InputMap action"):
godot --headless --quit-after 2 --verbose

# Un --script que haga print(InputMap.get_actions()) confirma qué acciones existen de verdad:
godot --headless --script res://test_input.gd --quit-after 1

# Tras editar project.godot a mano:
godot --headless --import
```

Checklist rápido: (1) ¿acción existe? → `print(InputMap.get_actions())` o lee `[input]` en `project.godot`. (2) ¿tiene eventos? → `action_get_events(a).size() > 0`. (3) ¿WASD raro en otro layout? → `physical_keycode`. (4) ¿`get_vector` raro? → deadzone explícita. (5) ¿rebind pegado? → `action_erase_events` (plural) + `Input.action_release`. (6) ¿prompts no cambian? → reacciona al último `InputEvent`, filtra drift. (7) ¿no vibra? → es el dispositivo/SO, itera `get_connected_joypads()`, prueba USB. (8) ¿co-op cruza inputs? → filtra `event.device`.

### Addon vs construirlo

- **Remapeo + persistencia básica:** constrúyelo (ver `examples`). Son ~80 líneas con `ConfigFile` y te dan control total del formato del save, sin depender de un addon que quede abandonado. Es lo que hacen la mayoría de RPGs open-source.
- **Resource de mapping listo:** [`KoBeWi/Godot-Input-Remap`](https://github.com/KoBeWi/Godot-Input-Remap) (KoBeWi es contribuidor core). Aviso real de su README: *"physical keycodes are not supported"* — limitación para teclados no-QWERTY. Si necesitas `physical_keycode`, el snippet propio sí lo preserva porque serializa el `InputEvent` entero.
- **Iconos de prompts (Xbox/PS/Switch/teclado):** usa assets gratis (Xelu's Free Controller & Key Prompts) + tu lógica de esquema. No reinventes los sprites.
- **Mandos exóticos sin mapear** (`get_joy_name` = "Unknown Joystick"): carga [`mdqinc/SDL_GameControllerDB`](https://github.com/mdqinc/SDL_GameControllerDB) con `Input.add_joy_mapping(sdl_string, true)`.

Sobre serialización: guardar `InputEvent` directo en `ConfigFile` funciona (son `Resource`) y es la vía nativa — empieza por ahí. Solo si tu RPG open-source evoluciona mucho y quieres saves diffeables/portables entre refactors, considera serializar a mano (tipo + `physical_keycode`/`button_index`/`axis`+`axis_value` a JSON). No es necesario de entrada.

**Veredicto ponytail:** el `InputMap` + `Input` nativos cubren teclado, ratón y gamepad enteros sin una línea de sistema propio — define acciones en `project.godot`, lee con `get_vector`/`is_action_pressed`, y la única pieza que SÍ debes escribir es ~80 líneas de `ConfigFile` para persistir el remapeo (porque el InputMap no persiste, a propósito). Antes de meter un addon de input, recuerda que esa categoría tiende a quedar sin mantenimiento y que el engine ya te lo da todo. La mejor línea de remapeo es la que no escribes: reusa `var_to_str`/Resources de Godot para serializar, no inventes formato.

## 21. Arranque de proyecto y addons curados

> Contexto verificado (Godot 4.6, released 2026-01-27, mantenimiento ~4.6.x): GDScript 2.0 + C# .NET 8. **Jolt es el solver 3D por defecto en proyectos nuevos.** `.uid` por todas partes desde 4.4; en 4.6 los `.tscn`/`.tres` **ya no escriben `load_steps`** y las referencias externas viven en `uid://`. Renderers: Forward+ / Mobile / Compatibility (web exige Compatibility; **C#/.NET NO exporta a web**). D3D12 es el driver por defecto en Windows en proyectos nuevos.

### El error mental nº1 de una IA que NO ve el editor

El editor de Godot hace cosas **invisibles desde la CLI y el árbol de archivos**, y ahí es donde una IA se atasca. Tres invariantes que debes internalizar antes de cualquier checklist:

1. **`project.godot` a mano no basta.** La carpeta `.godot/` (caché + tabla UID + importados) **no existe hasta el primer arranque que importa**. Una IA que clona un repo y lanza `--export-release` en frío SIEMPRE falla la primera vez.
2. **Operaciones de UI = escrituras de texto plano a `project.godot`.** Autoloads, plugins habilitados, renderer: todo es editable a mano si sabes la sección y la clave exactas (las doy abajo). No necesitas el editor para esto.
3. **Las referencias escena↔script viven en `uid://`, no en rutas.** Gitignorar los `.uid` rompe enlaces de forma silenciosa para los colaboradores.

**Cómo desatascarse sin abrir el editor (canónico):**

```bash
# 1. Importar assets y generar .godot/, *.import, resolver uid:// — en SU PROPIO proceso.
#    NO combinar import con export en la misma invocación.
godot --headless --import --path . --verbose

# 2. Validar que un script compila (parse/typecheck, NO ejecuta el juego)
godot --headless --check-only --script res://autoload/event_bus.gd --path .

# 3. Smoke test: arrancar sin ventana y salir; 0 líneas de error = sano
godot --headless --path . --quit-after 2 2>&1 | grep -Ei "ERROR|invalid UID|Unable to load"
```

`--import`, `--check-only`, `--headless`, `--script`/`-s`, `--export-release`, `--export-debug`, `--verbose`, `--quit-after N` son flags **reales** de la CLI 4.6.

**Trampa de `--check-only` con autoloads (falso positivo que atasca a la IA):** `--check-only` NO conoce los singletons del bloque `[autoload]`. Validar un script que referencia otro autoload (p.ej. `game_state.gd` usa `EventBus.item_picked.connect(...)`) escupe un falso error `Identifier "EventBus" not declared in the current scope` aunque el código sea correcto (GH-78587). Una IA que valida a ciegas creerá que el script está roto. Regla: usa `--check-only` como señal fiable SOLO en scripts sin dependencias de autoload (como `event_bus.gd`). Para los que referencian otros autoloads, valida con un arranque headless completo (`--headless --quit-after 2`) o ignora específicamente los errores `Identifier ... not declared` que apunten a nombres de autoload.

### Checklist accionable (orden estricto — el orden importa más que cualquier addon)

```
[ ] 1. Decide TARGET primero (desktop / web / móvil). Esto fija renderer + lenguaje
       y es casi irreversible a mitad de proyecto. (web ⇒ Compatibility + GDScript, sin C#)
[ ] 2. godot --version  → confirma 4.6.x
[ ] 3. Crea el proyecto con el renderer correcto (§ tabla). En el Project Manager,
       marca "Version Control Metadata: Git" → genera base .gitignore/.gitattributes.
[ ] 4. Arráncalo UNA VEZ para generar .godot/ (editor, o headless --import).
[ ] 5. Corrige .gitignore/.gitattributes (el por defecto NO cubre bien .uid) ANTES del 1er commit.
[ ] 6. git init → primer commit "scaffold" vacío (para poder revertir un addon que rompa el editor).
       Si usarás binarios grandes: git lfs install + commitea .gitattributes ANTES de meter binarios.
[ ] 7. Estructura de carpetas con mkdir (+ .gitkeep). No esperes al editor.
[ ] 8. Autoloads mínimos en [autoload]: EventBus, GameState/Game, SaveManager (3, no 12).
[ ] 9. Instala addons UNO A UNO, commit entre cada uno. Solo los que usas HOY.
[ ] 10. godot --headless --import --path .  (proceso aparte) → genera .uid/.import.
[ ] 11. Commit incluyendo .uid + .import.
[ ] 12. CI: cachea .godot/imported/; import en proceso separado del export; nunca --quit-after 1 para reimport.
```

**Pitfall de orden (LFS):** si metes GLB/audio grandes ANTES de `git lfs track`, quedan en el historial como blobs normales; migrar después requiere `git lfs migrate import --include="*.glb"` (reescribe historia). La doc recomienda **commitear `.gitattributes` antes que el resto**.

### Renderer + lenguaje por target (decisión casi irreversible)

La clave exacta en `project.godot`:

```ini
[rendering]
renderer/rendering_method="forward_plus"          ; "mobile" | "gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

| Target del RPG | `rendering_method` | C#/.NET | Notas 4.6 |
|---|---|---|---|
| Desktop (Win/Linux/Mac) | **`forward_plus`** | Sí | Default recomendado. D3D12 es el driver por defecto en Windows en proyectos nuevos. |
| Móvil (Android/iOS) | **`mobile`** | Sí | Cambiar de `gl_compatibility` a `mobile` **reduce dispositivos Android soportados** (GH-111729). Glow más rápido en 4.6. |
| **Web (browser/itch)** | **`gl_compatibility`** | **NO** | Forward+/Mobile no funcionan en web. **C#/.NET no exporta a web** (GH-70796 abierto). |

Regla: un proyecto Forward+ **no exporta a web**. Si quieres demo web, vas **Compatibility + GDScript en todo el proyecto** o renuncias a la web. El atasco invisible: una IA elige `forward_plus`, exporta a web y obtiene pantalla negra / shaders rotos en runtime, no un error de build claro.

**Jolt (proyecto nuevo):** ya viene activo, confirmable en `project.godot`:

```ini
[physics]
3d/physics_engine="Jolt Physics"
```

Los nodos (`RigidBody3D`, `CharacterBody3D`) son los mismos; cambia el backend de `PhysicsServer3D`. No traslades supuestos exactos de Godot Physics (p.ej. comportamiento de `move_and_slide` en bordes) — Jolt es más determinista y a veces más "rígido".

### `.gitignore` / `.gitattributes` — el atasco silencioso que corrompe el repo entero

No da error inmediato: rompe a los clones/colaboradores siguientes. El error de bulto es copiar un `.gitignore` de Godot 3.x o genérico que incluya `*.import` y/o `*.uid`.

- **`*.uid` ignorados** → cada clon regenera UIDs nuevos → **se rompen TODOS los enlaces `uid://` escena↔script**. La escena abre pero las referencias apuntan a IDs que solo existían en la máquina del autor. **Commitea los `.uid`.**
- **`*.import` ignorados** → cada clon reimporta con defaults; texturas/fuentes pueden desaparecer y los diffs explotan. **Commitea los `.import`.** (El contenido pesado vive en `.godot/imported/`, que SÍ se ignora.)
- **`.godot/` versionado por error** → conflictos de merge constantes en `uid_cache.bin`, `filesystem_cache`. **Ignora `.godot/`** y arregla el reimport con el ciclo headless, no versionando el caché.

**Regla 4.6 de oro: ignora `.godot/`, commitea `*.import` y `*.uid`.** Ver `examples` para los archivos compile-ready.

**Matiz `export_presets.cfg`:** En 3.x/4.0 guardaba credenciales (keystore passwords) → se ignoraba. Desde **4.1 los secretos se separan en `export_credentials.cfg`**. En 4.6: **versiona `export_presets.cfg`** (presets reproducibles para CI), **ignora `export_credentials.cfg`** y nunca commitees keystores Android (`*.keystore`/`*.jks`) — esos van por variables de entorno / secrets del CI. Si tu equipo aún tiene secretos inline en el preset, mantenlo ignorado hasta limpiarlo.

### Autoloads mínimos (no el "cajón de sastre")

La clave exacta en `project.godot` — **el orden de las líneas = orden de inicialización**:

```ini
[autoload]
EventBus="*res://autoload/event_bus.gd"
GameState="*res://autoload/game_state.gd"
SaveManager="*res://autoload/save_manager.gd"
```

El `*` prefijo = habilitado (sin él se registra pero no se carga). Para una IA esto es oro: "subir el botón de Autoload" del foro = **reordenar líneas en este bloque**. No necesitas editor.

Antipatrón clásico: un único `Global.gd` con vida, oro, inventario, diálogo, flags de debug = junk drawer inmantenible. Separa por responsabilidad y comunica por **señales**, no polling. Mínimo viable para un RPG: **3 autoloads, no 12**. Pon `EventBus` (señales puras, cero dependencias) PRIMERO; el resto se comunica vía señales → rompe ciclos.

```gdscript
# autoload/event_bus.gd — bus de señales global, desacopla sistemas
extends Node

signal player_died
signal item_picked(item_id: StringName, amount: int)
signal scene_change_requested(target: String)
```

Reglas que causan crashes/deadlocks reales:
- **NUNCA accedas a otros autoloads en `_init()`** — aún no existen. Usa `_ready()`/`_enter_tree()`. Síntoma: `Cannot call method 'xxx' on a null value` durante el arranque.
- **NUNCA dependencias circulares** entre managers (GameState↔SaveManager) → deadlock de inicialización.
- **`class_name` + autoload del MISMO script** → error `Class "X" hides an autoload singleton`. Usa `class_name` para tipos reusables (`Item`, `Stats`) y autoload para servicios; no ambos en el mismo archivo.

### Estructura de carpetas (híbrida: feature-local + type-global)

La doc oficial sugiere organización **por feature/escena** (recursos exclusivos junto a su escena). Para un RPG, la híbrida gana: entidades concretas feature-local, recursos compartidos por tipo. Ver `examples` para el árbol completo.

Convenciones que evitan bugs reales:
- **snake_case** para archivos/carpetas (excepto scripts C#) → evita el bug de **case-sensitivity**: en Windows/macOS `Player.tscn` y `player.tscn` colisionan; en Linux/CI no. Si una escena referencia `res://Scenes/...` y la carpeta real es `scenes/`, el export en Linux/CI falla con recurso no encontrado.
- **PascalCase** para nombres de nodo (coincide con built-ins).
- Datos como `Resource` tipados (`.tres`) en `data/`, separados de la lógica en `systems/`. `@abstract` (desde 4.5) para clases base (`Item`, `State`, `Ability`) evita instanciar la base por error.

### Addon vs construirlo

| Caso | Recomendación |
|---|---|
| Cámara 3ª persona simple (follow + offset) | **Construir**: `Camera3D` + `SpringArm3D` nativos. Phantom Camera solo si necesitas blends/framing multi-target. |
| Inventario trivial (pocos slots, sin stacking) | **Construir** con `Resource` (`class_name Item`) + `Array[Item]`. GLoot si necesitas grid, constraints, stacking, drag&drop serio. |
| FSM de UN personaje (4-5 estados) | **Construir** un `match state:` o nodos. LimboAI/Beehave cuando hay muchos agentes y árboles reutilizables. |
| Diálogos lineales cortos | **Construir** con `RichTextLabel` + JSON. Dialogic cuando hay branching, retratos, condiciones, localización. |
| Save/load | **Construir** (autoload + `FileAccess`/`ResourceSaver` + tus `Resource`). Ningún addon encaja con tu esquema de datos sin pelear; es ~100 líneas auditables. |
| Testing | **Siempre addon** (GUT/gdUnit4). Nunca escribas tu propio runner. |

Regla: no metas un addon hasta tener un caso de uso real que ya te duele. Cada addon es deuda atada a su soporte de versión de Godot. Para web, evita GDExtension nativo (LimboAI) y C#.

### Lista CURADA de addons 4.6 (repos reales verificados)

Tabla completa con URLs en `examples`. Selección rápida:
- **Diálogos:** Dialogic 2 (`dialogic-godot/dialogic`). Alternativa más ligera: `nathanhoad/godot_dialogue_manager`. Elige uno.
- **Cámara:** Phantom Camera (`ramokz/phantom-camera`) — estilo Cinemachine.
- **IA (BT/FSM):** **LimboAI** (`limbonaut/limboai`, **C++ GDExtension/módulo — necesita binario por plataforma**, soporte 4.6 desde v1.6.0) **vs Beehave** (`bitbrain/beehave`, branch `godot-4.x`, **GDScript puro, sin binario** → mejor para CI/agentes y para web). **No los uses a la vez** (ver pitfall).
- **Inventario:** GLoot (`peter-kish/gloot`, 4.4+ en releases actuales; la entrada AssetLib aún lista 4.2). (El autor es `peter-kish`, NO "peter1745"; Beehave es de `bitbrain`.)
- **Testing:** GUT (`bitwes/Gut`) si es GDScript puro y quieres mínima fricción; **gdUnit4** si tienes C#/mixto o quieres runner de CI + JUnit XML + GitHub Action oficial.

### Pitfalls y mensajes de error literales

**A) Recurso roto tras clonar / cambiar de versión:**
```
ERROR: Cannot get class 'X'.
res://scenes/foo.tscn:NN - Parse Error: [ext_resource] referenced non-existent resource at: uid://...
ERROR: Cannot load script "res://...": invalid UID: uid://xxxxx - using text path instead
```
Fix: `godot --headless --import --path .` (proceso propio) para regenerar la tabla UID. Si persiste, faltaba commitear `.uid`/`.import`.

**B) El proceso headless se cuelga indefinidamente (no error, no exit):**
Causa documentada: tras `git clone` git pone el **mismo mtime a todos los archivos** (GH-100465) y el importador se atasca. También cuelga el export en headless sin carpeta `.godot/` (GH-95287).
Fix: importa en su propio proceso con `--import`; si nunca se abrió, fuerza dos ciclos de tick: `godot --headless --editor --quit-after 2 --path .`. **Nunca `--quit-after 1` para reimport** — aborta a medias (GH-77508). En CI, cachea `.godot/imported/` entre runs.

**C) `load_steps` desaparece en diffs masivos tras abrir en 4.6:**
Al guardar, 4.6 reescribe el descriptor quitando `load_steps=` → diff en CADA escena con dependencias. Es **esperado** (godot-docs #11707). Higiene: `Project > Tools > Upgrade Project Files`, abre/guarda todo en un commit aislado "migrate to 4.6 tscn format" para no contaminar commits de features. Headless no tiene el menú; equivalente: ciclo `--headless --editor --quit-after 2`.

**D) Plugin no carga tras copiarlo:**
```
Unable to load addon script from path: 'res://addons/x/plugin.gd'. This might be due to a code error in that script. Disabling the addon at 'res://addons/x/plugin.cfg' to prevent further errors.
```
Causas reales: (1) no habilitado en `[editor_plugins]`; (2) `plugin.cfg` apunta a un `script=` inexistente; (3) **GDExtension/C++ (LimboAI) sin el binario `.so/.dll` de tu plataforma** → el `.gdextension` no carga; (4) plugin C# sin compilar (`dotnet build`, o borra `.godot/mono`); (5) versión incompatible (LimboAI <1.6.0 rompe en 4.6).
Habilitar headless editando `project.godot`:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/phantom_camera/plugin.cfg", "res://addons/dialogic/plugin.cfg")
```
Al instalar desde AssetLib, importa **solo el directorio `addons/<x>/`** y nada más.

**E) LimboAI + Beehave juntos = colisión de clases:** ambos registran su propia clase `Blackboard` → error de `class_name` duplicado al cargar (limboai#72, beehave#322). **Elige uno.**

**F) Shader heredado de pre-4 que no compila:**
```
Use of reserved keyword: 'SCREEN_TEXTURE'   (o: Use of undeclared identifier 'SCREEN_TEXTURE')
```
Fix 4.x: built-ins `SCREEN_TEXTURE`/`DEPTH_TEXTURE` eliminados → uniforms con hint:
```glsl
uniform sampler2D screen_tex : hint_screen_texture;
uniform sampler2D depth_tex  : hint_depth_texture;
```

**G) AnimationPlayer en 4.6 (GH-110767):** las **propiedades de nombre de animación** (`current_animation`, `assigned_animation`, `autoplay`, señal `current_animation_changed(name: StringName)`, `get_queue() -> StringName[]`) pasaron de `String` a `StringName`. **NO afecta nombres de track.** Asignar `anim.assigned_animation = "walk"` auto-castea, pero comparaciones estrictas `==` con tipos mezclados o serialización antigua fallan, con `Animation not found: 'animation_name'`. Fix: usa literales `&"walk"` (StringName) al asignar/comparar estas props.

**H) C#/.NET a web no soportado (GH-70796):** el preset falla o el `.wasm` no embebe el runtime .NET. Fix: para web usa Compatibility + **GDScript**.

### Cómo no quedarte atascado

Comandos que una IA SÍ puede correr sin ver el editor:

```bash
# Validar sintaxis GDScript 2.0 de un script SIN dependencias de autoload.
# OJO: --check-only no resuelve singletons [autoload] → un script que use
# otro autoload (EventBus, GameState...) dará un FALSO "Identifier ... not
# declared" (GH-78587). Para esos, valida con --quit-after 2, no --check-only.
godot --headless --check-only --script res://autoload/event_bus.gd --path .

# Confirmar que .uid/.import están trackeados (deben devolver resultados)
git ls-files '*.uid' '*.import'

# Confirmar que .godot/ está ignorado y *.uid / *.import NO
git status --ignored

# Salud general: 0 líneas de salida = sano
godot --headless --path . --quit-after 2 2>&1 | grep -Ei "ERROR|invalid UID|Unable to load"
```

Nunca asumas que `árbol de archivos == estado del editor`. Tras tocar cualquier cosa a ciegas: `--import` (proceso propio) + `--check-only`.

**Veredicto ponytail:** el mejor addon es el que no instalas. Decide target/renderer/lenguaje primero (irreversible), escribe `.gitignore`/`.gitattributes` correctos antes del primer commit (commitea `.uid` y `.import`, ignora `.godot/`), y monta solo 3 autoloads (`EventBus`, `GameState`, `SaveManager`) comunicados por señales. Para cámara, inventario simple, FSM de un personaje y save/load: nodos nativos + `Resource`. Reserva addons (Dialogic, Phantom Camera, LimboAI/Beehave, GLoot, GUT/gdUnit4) para cuando el dolor sea real, e instálalos uno a uno con commit entre cada uno. Y recuerda el invariante que tumba a las IAs headless: `.godot/` no existe hasta el primer import — importa en proceso propio antes de exportar, nunca con `--quit-after 1`.

## 22. Localización (i18n)

Localizar un RPG 3D en Godot 4.6 es, en el 90% de los casos, un problema de **pipeline y fuentes**, no de API. Una IA que no ve el editor se atasca porque `tr()` "no traduce" y empieza a tocar código, cuando casi siempre la causa es que la traducción no está registrada, el `.csv` no se reimportó, el locale de test está vacío, o faltan glyphs (que ni siquiera es i18n). La señal diagnóstica que hay que internalizar:

> **¿`tr()` devuelve la CLAVE o devuelve CUADRITOS (□□□)?**
> Clave → problema de carga/locale/registro. Cuadritos → problema de fuente (fallback de glyphs). Son fallos distintos con fixes distintos.

### Modelo mental

Godot **no traduce strings: traduce claves** vía `TranslationServer`. Flujo real:

1. Escribes **claves** (`START_GAME`, no la frase) en código/escena.
2. `tr("START_GAME")` consulta `TranslationServer` con el locale actual.
3. `TranslationServer` busca en los `*.translation` (binarios) cargados para ese locale.
4. Si no hay match → `tr()` **devuelve la clave tal cual, sin error**. Este silencio es el atasco número uno.

Tres formas de obtener texto traducido:
- `tr()` / `tr_n()` (GDScript), `Tr()` / `TrN()` (C#).
- **auto-translate**: cualquier `Control`/`Window` con texto traduce su propiedad `text`/`title` según `auto_translate_mode`.
- **POT/CSV scanner**: extrae strings de `tr()` y de propiedades de texto de nodos para generar el catálogo.

### Enfoque nativo recomendado

El pipeline CSV/PO + `TranslationServer` + auto-translate es **nativo y suficiente** para un RPG; no necesitas addon para el runtime. La decisión de fondo es la fuente de strings:

- **gettext (PO/POT) — recomendado para un RPG con mucho texto y/o traductores comunitarios.** Un archivo por locale (diffs limpios en Git), soporta `msgctxt` (contexto), `msgid_plural` (plurales reales por idioma con N formas), y comentarios para traductores. Herramientas maduras: Poedit, Lokalize, Weblate (selfhosted, patrón estándar en open-source).
- **CSV — solo para proyectos pequeños o equipos que editan en Sheets.** Genera conflictos de merge feos y el escapado de comas/saltos rompe el parseo.

Pipeline canónico:

1. **Nunca hardcodear** texto visible. Claves en `MAYÚSCULAS_CON_GUION` para distinguirlas de frases (no hay restricción técnica, es convención anti-ambigüedad).
2. Fuente: CSV **o** PO/POT bajo `res://`.
3. Godot **importa automáticamente** y genera `*.translation` binarios en `.godot/imported/`.
4. Registrar esos `.translation` en **Project Settings > Localization > Translations** (persiste en `project.godot` como `locale/translations`).
5. Runtime: `TranslationServer.set_locale(locale)`.

#### APIs exactas (4.6)

`Object`:
- `tr(message: StringName, context: StringName = "") -> String`
- `tr_n(message: StringName, plural_message: StringName, n: int, context: StringName = "") -> String`

`TranslationServer` (singleton global):
- `set_locale(locale: String)` / `get_locale() -> String`
- `translate(message, context = "") -> StringName`
- `translate_plural(message, plural_message, n, context = "") -> StringName`
- `get_loaded_locales() -> PackedStringArray`
- `set_pseudolocalization_enabled(enabled: bool)` (QA: detecta strings sin traducir y overflow de UI)
- `compare_locales(a, b) -> int`, `standardize_locale(locale) -> String`

`Node` (auto-translate, ya unificado en la línea 4.x): propiedad `auto_translate_mode` con enum `AutoTranslateMode`:
- `AUTO_TRANSLATE_MODE_INHERIT` (default — hereda; la raíz equivale a ALWAYS)
- `AUTO_TRANSLATE_MODE_ALWAYS`
- `AUTO_TRANSLATE_MODE_DISABLED`

La antigua `Control.auto_translate` (bool) está **deprecada** — usa `auto_translate_mode`. Esto es exactamente donde la training data y los tutoriales viejos dan API obsoleta.

`OS.get_locale()` (p.ej. `"es_ES"`) / `OS.get_locale_language()` (solo `"es"`) para detectar el idioma del sistema al arrancar.

#### CSV (UTF-8, sin BOM)

```csv
keys,en,es,ja,?context,?plural
START_GAME,Start Game,Iniciar partida,ゲーム開始,,
MENU_OPEN,Open,Abrir,開く,verb,
GREET_PLAYER,"Hello, {0}!","¡Hola, {0}!","こんにちは、{0}！",,
```

Reglas que rompen a la gente:
- La primera columna **debe** llamarse `keys`. Las demás cabeceras son **códigos de locale válidos** (`en`, `es`, `ja`, `pt_BR`…), no nombres descriptivos. Un header como `comment` se interpreta como locale inválido y genera un `.translation` basura.
- **UTF-8 sin BOM**. Con BOM, la primera clave queda como `﻿keys` y toda la columna de claves se inutiliza (todo devuelve la clave). Mojibake (`Ã©`, `æ–‡å­—`) = encoding mal.
- Comas/saltos dentro de celda → entrecomillar con `"`; comilla interna se escapa duplicándola (`""`).
- Delimitador puede ser coma, `;` o tab (`ResourceImporterCSVTranslation`). Excel-ES suele guardar `;` + BOM: revisa ambos.
- **No dejes celdas vacías**: el comportamiento de "vacío" difiere entre CSV y PO (en PO `msgstr ""` devuelve la clave). Repite el texto fuente explícitamente.
- `?context` ya existía; `?plural` se añadió en PR #101471 (línea 4.x previa a 4.6, no es nuevo de 4.6). Solo se respeta la **primera** columna de cada tipo. Ver veredicto de plurales abajo.

#### gettext (PO/POT)

`Project Settings > Localization > POT Generation` → añadir escenas/scripts a escanear → **Generate POT** (botón en el editor). Traducir el `.pot` en Poedit → `es.po`, `ja.po` → añadir los `.po` en **Translations** (Godot los compila a `.translation`).

```po
msgid "%d enemy"
msgid_plural "%d enemies"
msgstr[0] "%d враг"
msgstr[1] "%d врага"
msgstr[2] "%d врагов"
```
Header crítico (CLDR por idioma):
```po
"Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<12 || n%100>14) ? 1 : 2);\n"
```
**El número de `msgstr[N]` DEBE coincidir con `nplurals`** del header, o el plural sale mal/falla. Valida antes de importar: `msgfmt -c es.po -o /dev/null` (si no imprime nada, está bien).

#### Runtime y cambio de idioma (el patrón que sí funciona)

`set_locale()` re-traduce automáticamente los `Control`/`Window` con auto-translate activo (reciben `NOTIFICATION_TRANSLATION_CHANGED`). **Pero el texto que asignaste por código con `tr()` ya es un String resuelto — NO se re-traduce solo.** Hay que re-asignarlo:

```gdscript
func set_language(loc: String) -> void:
    TranslationServer.set_locale(loc)   # "es", "ja", "en_US"...
    _refresh_texts()                     # re-aplica lo seteado por código

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        _refresh_texts()
```
Persiste el locale en `user://settings.cfg` y aplícalo en un autoload `_ready()` **antes** de mostrar la UI.

### Pitfalls y mensajes de error literales

- **`tr("START_GAME")` muestra `START_GAME` literal (sin error en consola).** Causas, por probabilidad: (a) el `.translation` no está en `locale/translations`; (b) el `.csv`/`.po` no se reimportó (`godot --headless --import`); (c) **Localization > Locale > Test** vacío y sin `set_locale()` (GH-80985); (d) locale no coincide (registraste `es_ES` pero pides `es`). El fallback `xx_YY`→`xx` fue arreglado en 4.4+ (PR #98743) y ya funciona en 4.6, pero sigue siendo buena práctica defensiva usar locales sin región salvo necesidad (GH-90677, ya cerrado); (e) la clave contiene `\n` (GH-47883 era `[3.x]`, legacy — aun así usa claves planas por higiene).
- **Texto sale como `□□□` (tofu) o invisible en CJK/árabe.** NO es i18n: la fuente no tiene esos glyphs. Fix en §fuentes.
- **`Error parsing CSV` / primera clave corrupta / mojibake.** CSV no es UTF-8 o tiene BOM. Re-guardar UTF-8 sin BOM.
- **`tr_n` da forma plural incorrecta o falla.** `nplurals` del header ≠ número de `msgstr[]`. Valida con `msgfmt -c`.
- **`ERROR: Cannot open file '...'` cargando recursos remapeados/fuentes en export** con "Convert Text Resources To Binary On Export" activado (GH-63606). Revisar remaps o desactivar esa opción.
- **Cambié locale y la UI no cambia.** Los labels seteados por código no se re-traducen solos: re-aplica en `NOTIFICATION_TRANSLATION_CHANGED`.
- **El nombre del héroe "Cloud" se traduce a "Nube".** auto-translate está ON por defecto y cualquier `text` que coincida con una clave se traduce. Pon `AUTO_TRANSLATE_MODE_DISABLED` en ese Label. Ojo bug GH-95357: `DISABLED` no se hereda más allá del primer hijo → ponlo **directamente** en el nodo problemático, no en un ancestro.
- **El POT tiene claves espurias que no pusiste.** Nodos en modo `Inherit` se cuelan como `msgid` (GH-108744).
- **`LineEdit.placeholder_text` no respeta el locale** (GH-23984): asignar con `tr()` en `_ready()` y re-aplicar al cambiar locale.
- **No hay formateo de números/fechas por locale** (no hay ICU/`Intl`; `TextServer.format_number()` solo mapea dígitos a glyphs alternativos, no cambia `1,000.5` ↔ `1.000,5`; proposals GH-12429, GH-28660 abiertas). Formatea a mano por locale o mete el formato como string traducible. Fechas: `Time.get_datetime_dict_*` + plantilla por idioma; los nombres de mes/día localízalos como claves.

#### Fuentes y glyphs (el pitfall visual que una IA ciega no detecta)

El texto japonés/coreano/árabe sale como `□□□` porque la fuente primaria no tiene esos glyphs. Fixes:
- En **desktop/móvil** Godot usa fuentes del SO como fallback automático (`SystemFont`) → CJK/emoji suelen resolverse solos. En **export web NO se cargan system fonts** → debes empaquetar la fuente.
- Añade **fallbacks Noto** al `FontFile`/`Theme`/`LabelSettings`: `Noto Sans JP`, `Noto Sans SC`, `Noto Sans KR`, `Noto Sans Arabic`. Una sola fuente con cadena de fallbacks que cubra todos los idiomas.
- **NO remapees fuentes por locale**: cambiar de idioma en runtime rompe la fuente remapeada (GH-80130). Usa fuente única + fallbacks.
- **MSDF + CJK = problemas**: atlas gigante; el bug de "cajas grises" en `Label3D` (GH-100726) fue una regresión de 4.4-dev arreglada en PR #100678, pero el punto de fondo sigue en pie: un atlas MSDF con CJK es pesadísimo. Para diálogos 3D usa DynamicFont (TTF/OTF) que rasteriza on-demand.
- Árabe/devanagari requiere **TextServer Advanced** (build por defecto lo trae; builds minimal/web pueden no traerlo → shaping roto, letras inconexas).

### Cómo no quedarte atascado (headless / sin editor)

Pasos que **solo existen en la GUI** pero persisten en `project.godot` editable:

```ini
[internationalization]
locale/translations=PackedStringArray("res://i18n/game.es.translation", "res://i18n/game.ja.translation")
locale/test="es"
locale/translations_pot_files=PackedStringArray("res://main.gd", "res://ui/menu.tscn")
```

- **Regenerar `.translation` sin editor:** `godot --headless --import --path /ruta/proyecto` (genera los binarios en `.godot/imported/` a partir de CSV/PO). Sin esto el `.translation` referenciado no existe.
- **Registrar traducciones sin GUI:** editar `locale/translations` y `locale/test` en `project.godot` a mano. Usa **rutas `res://` explícitas, no UID**, para robustez en CI.
- **Verificar el pipeline:** un `--script` que cargue y haga `TranslationServer.set_locale("es"); print(tr("START_GAME"))`:
  ```
  godot --headless --quit-after 1 --script res://tools/i18n_check.gd --verbose
  ```
- **Trampa de orden:** editar el CSV NO basta. Hay tres pasos: (1) `--import` regenera `.translation`; (2) registrar en `project.godot`; (3) `locale/test` o `set_locale`. Saltarse cualquiera → clave cruda.
- **POT por CLI NO EXISTE** (GH-10986: ningún flag, ninguna API GDScript). Una IA que intente `godot --headless --generate-pot` fracasa. En CI: usa flujo **CSV + `--import`**, o genera/compila PO con **gettext externo** (`xgettext` para extraer, `msgfmt es.po -o es.mo` para compilar) y versiona el catálogo en Git.
- **`.uid` / Upgrade Project Files:** desde 4.4 los recursos usan `uid://` + ficheros `.uid` y 4.6 ya no escribe `load_steps` en `.tscn`. Si editas rutas a mano y rompes los `.uid`, los `.translation` referenciados por UID no cargan → `godot --headless --import` o **Project > Tools > Upgrade Project Files**.

#### C# — avisos de plataforma

- Firmas: `Tr(message, context)`, `TrN(message, pluralMessage, n, context)`, `TranslationServer.SetLocale(...)`. `Tr()` == `tr()`.
- **C# NO corre en export web** (renderer Compatibility, sin .NET). Si el RPG apunta a web, la capa de i18n debe ser GDScript.
- Extracción de strings C# en el POT scanner: el dossier de docs afirma que 4.6 ya extrae `Tr`/`TrN`; el veterano sostiene que seguía sin extraerse a junio 2026. **No confíes en ello**: mantén las claves usadas en C# también referenciadas en una escena escaneable, o añade esos `msgid` al `.pot` a mano.

### Addon vs construirlo

- **Construir (por defecto):** el pipeline nativo (CSV/PO, `tr`/`tr_n`, `TranslationServer`, auto-translate, pseudolocalization) es suficiente. No necesitas addon para el runtime.
- **Edición de catálogo:** *Godot4LocalizationEditor* (`VP-GAMES`, asset #1199) o *Localization Editor* (asset #1555) dan una tabla GUI; útiles para autoría manual, inútiles para flujo headless (son GUI).
- **CSV↔gettext:** `Wiechciu/csv-to-gettext-converter` si autoras en Sheets pero entregas PO a traductores en Git.
- **Traductores:** Weblate (selfhosted) o Poedit/Lokalize. Para open-source comunitario, Weblate + PO es el estándar.
- **Evita** soluciones que reimplementan su `TranslationServer` o cargan JSON propio en runtime: pierdes auto-translate de nodos y el scanner de catálogo.
- Ningún addon resuelve el gap de POT-por-CLI; es del engine (GH-10986).

**Veredicto ponytail:** no escribas tu propio sistema de traducción. Usa claves + `tr()`/`tr_n()` + `TranslationServer` y deja que el auto-translate de los nodos `Control` haga el trabajo gratis; tú solo re-aplicas en `NOTIFICATION_TRANSLATION_CHANGED` los textos que seteaste por código. Para un RPG serio elige **PO/gettext** (plurales reales, contexto, Git, Weblate); el CSV es la opción rápida pero su columna `?plural` (añadida en PR #101471, línea 4.x previa a 4.6) está menos probada que el flujo gettext, así que para plurales robustos sigue siendo más seguro PO. El 90% de tu esfuerzo anti-stuck no está en la API sino en tres cosas: reimportar (`--import`), registrar en `project.godot`, y empaquetar fuentes con fallbacks Noto. Lo que NO existe (formateo de números/fechas por locale, POT por CLI) no lo busques: hazlo con gettext externo o a mano.

## 23. Multiplayer y co-op

Godot 4.6 trae el stack *high-level multiplayer* sin cambios de firma respecto a 4.3/4.4/4.5 (no hubo refactor de red), así que las páginas `/en/stable/` y `/en/4.6/` son canónicas. El reto real para una IA que **no ve el editor** es que ~70% del setup multiplayer vive en el inspector (replication config, spawn path, lista de escenas spawneables) y **falla en silencio** si lo dejas vacío. Toda esta sección prioriza construir esa configuración **por código**, que es lo que una IA ciega sí puede hacer de forma reproducible.

### Enfoque nativo recomendado

Cuatro piezas, y mezclarlas es el bug #1:

| Pieza | Clase | Rol mental |
|---|---|---|
| Transporte | `ENetMultiplayerPeer` | "el cable" (UDP fiable/no-fiable) |
| API | `MultiplayerAPI` / `SceneMultiplayer` (default) | enruta RPCs, emite señales de conexión |
| Spawn | `MultiplayerSpawner` | **qué nodos existen** (authority -> peers) |
| Sync | `MultiplayerSynchronizer` + `SceneReplicationConfig` | **qué valores tienen** esos nodos |
| Eventos | `@rpc` / `[Rpc]` | eventos puntuales (golpe, abrir cofre, chat) |

Regla: **Spawner = qué nodos; Synchronizer = qué valores; RPC = eventos.** No muevas al jugador cada frame por RPC — eso es Synchronizer. Nunca cubras la **misma** propiedad por RPC *y* Synchronizer a la vez (conflicto de escritura).

Arquitectura para un RPG co-op (las 3 lentes coinciden): **listen-server / server-authoritative ligero**. Uno hostea (server + jugador, peer id `1`), el resto son clientes. El cliente envía *intención* (input) por `@rpc("any_peer")`; el server valida y empuja el estado (posición/hp) por Synchronizer. P2P puro (cada peer autoridad de su propio personaje, sin árbitro de mundo) sirve para co-op casual entre amigos, pero pierdes árbitro de enemigos/loot/economía. Para un RPG con enemigos: **server autoritario del mundo, peer-authority solo del movimiento de su jugador** (vía un nodo `Input` hijo).

**Patrón de autoridad determinista (clave anti-desync).** El engine empareja nodos remotos por `path + name + authority`. Si dejas que Godot auto-nombre (`@Player@2`), los nombres divergen entre peers y el sync apunta a fantasmas. Solución universal: el **nombre del nodo ES el peer id**, y la autoridad se deriva localmente — nunca se anuncia por RPC asíncrono.

```gdscript
func _enter_tree() -> void:
    set_multiplayer_authority(name.to_int())  # determinista, idéntico en todos los peers
```

Asigna autoridad en `_enter_tree()` o dentro de `spawn_function`, **nunca en `_ready()`** (rompe el sync, ver pitfalls). Pero ojo: en `_enter_tree` el peer aún puede no estar configurado, así que pasa el `peer_id` como **dato del spawn**, no lo leas del entorno.

**Construir el `SceneReplicationConfig` por código** (lo que evita el atasco del inspector). El `NodePath` es `"NodoRelativo:propiedad"` — `".:position"`, no `"position"` a secas, o no sincroniza y no avisa:

```gdscript
func _setup_sync() -> void:
    var cfg := SceneReplicationConfig.new()
    var np := NodePath(".:sync_position")  # ver interpolación abajo
    cfg.add_property(np)
    cfg.property_set_spawn(np, true)       # incluida en el spawn inicial
    cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
    var hp := NodePath(".:health")
    cfg.add_property(hp)
    cfg.property_set_replication_mode(hp, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
    $MultiplayerSynchronizer.replication_config = cfg
    $MultiplayerSynchronizer.replication_interval = 0.05  # 20 Hz; 0.0 = cada frame (caro)
```

Modos: `REPLICATION_MODE_ALWAYS` (cada `replication_interval`), `REPLICATION_MODE_ON_CHANGE` (cada `delta_interval`, solo al cambiar), `REPLICATION_MODE_NEVER`. Construir el config por código además **esquiva** el bug del editor donde editar el config de una escena instanciada no se guarda (GH-84793) y la limitación de que añadir/quitar propiedades por código sobre un config existente no siempre re-arma la sync (GH-65725) — por eso se crea un config nuevo entero.

**Spawn 100% por código con `spawn_function`** (no requiere poblar la lista `_spawnable_scenes` del inspector):

```gdscript
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
    spawner.spawn_path = ^"../Players"      # anchor explícito; mismo nodo en todos los peers
    spawner.spawn_function = _spawn_player

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():             # SOLO el server spawnea
        spawner.spawn(id)                    # 'id' viaja como 'data' a TODOS los peers

func _spawn_player(data: int) -> Node:       # corre en CADA peer
    var p := preload("res://player.tscn").instantiate()
    p.name = str(data)                       # nombre determinista -> autoridad en _enter_tree
    return p                                  # NO hagas add_child: el spawner lo añade
```

Regla de oro de `spawn_function`: el Node devuelto **NO debe estar ya en el árbol** (Godot lo añade bajo `spawn_path`). Si haces `add_child` tú -> doble-parent/duplicados.

**Separación input/estado** (server-authoritative real): el personaje es autoridad del server; un nodo hijo `InputSynchronizer` es autoridad del cliente. El cliente escribe input ahí, su Synchronizer lo manda al server, el server lo procesa y replica la posición resultante.

```gdscript
# InputSynchronizer.gd — autoridad = cliente dueño
extends MultiplayerSynchronizer
@export var move_dir := Vector2.ZERO

func _process(_delta: float) -> void:
    if is_multiplayer_authority():
        move_dir = Input.get_vector("left", "right", "up", "down")
```

**Seguridad:** toda `@rpc("any_peer")` es superficie de ataque. Siempre `var sender := multiplayer.get_remote_sender_id()` y valida que `sender` posee la acción (ownership, vivo, en rango). `get_remote_sender_id()` lo da el engine (no spoofeable desde cliente vanilla) — confía en el id, **nunca** en los argumentos. Para juego serio: `SceneMultiplayer.auth_callback` para autenticar peers. **Nunca** `allow_object_decoding = true` con datos no confiables (es RCE: ejecuta código deserializado).

### Pitfalls y mensajes de error literales

- **`RPC '...' is not allowed on node ... Mode is 'Authority', authority is '<id>'.`** / `Unable to get RPC config for the function "..."` (GH-66224): el método no tiene `@rpc`/`[Rpc]`, la anotación difiere entre peers, o un no-authority llamó una RPC `"authority"`. La config `@rpc` debe ser **idéntica** en el script que ambos peers cargan.
- **RPC silencioso dentro de señales del *peer*** (GH-68750): no puedes lanzar RPC dentro del handler `peer_connected` del `MultiplayerPeer`. Conéctate a `multiplayer.peer_connected` (señal de la **API**), no a `peer.peer_connected`. Síntoma: id válido en log, RPC descartado sin error.
- **`Node not found` / `Failed to get cached path` / `get_cached_object: ID not found in cache of peer.`** (GH-76894, GH-78692): nombres no deterministas (fix: `name = str(peer_id)`), o el `spawn_path`/`MultiplayerSpawner` no existe con path idéntico en el cliente (fix: carga la **misma** escena raíz en host y cliente; espera a que ambos tengan el árbol antes de RPC al nodo recién spawneado).
- **`The MultiplayerSynchronizer ... is unable to process the pending spawn since it has no network ID.`** (GH-75067): asignar autoridad en `_ready()` —y, según el timing del spawn, incluso en `_enter_tree()` (es justo el patrón que reporta GH-75067)— puede disparar el error "no network ID". El fix robusto es **derivar la autoridad del nombre determinista del nodo** que `spawn_function` fija (`p.name = str(data)`): `set_multiplayer_authority(name.to_int())` en `_enter_tree()` como sitio primario, y `spawn_function` como fallback garantizado (corre en cada peer con el nombre ya puesto).
- **`Trying to call an RPC via a multiplayer peer which is not connected.`**: RPC antes de `connected_to_server`. Fix: espera la señal, o comprueba `multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED`.
- **RPC "no hace nada" en el emisor** (GH-98588): falta `"call_local"`.
- **`@rpc` en método de no-Node** (GH-89981): solo funciona en métodos de clases derivadas de `Node`.
- **Spawns dobles:** la IA pone `_add_player()` en ambos lados. Hay que gatear con `if multiplayer.is_server():`, y el host debe llamar `_add_player(1)` manualmente porque `peer_connected` NO dispara para el id propio.
- **El orden de los nodos `MultiplayerSynchronizer` en el árbol importa** (GH-75884): si el sync de input va antes que el de posición, el primer frame puede fallar. Prefiere un único synchronizer por nodo lógico.
- **C# default de `TransferMode` = `Reliable`; GDScript default = `unreliable`** (GH-docs#8874, verificado). No asumas paridad. En C# se invoca con `Rpc(MethodName.Foo, args)` / `RpcId(1, MethodName.Foo, args)` usando el `StringName` **generado** `MethodName.X`, **no** un literal ni `.rpc()`. El bug `Nonexisting function 'rpc' in base 'Callable'` (GH-84149) viene de portar la sintaxis GDScript a C#.
- **`rpc_id(0, ...)`**: `0` = broadcast a todos menos a ti. Para hablar **solo** con el server usa `rpc_id(1, ...)`.
- **Stuttering / teletransporte:** el Synchronizer **sobreescribe** `position` con el valor crudo y **no interpola** nativamente (proposal GH-7280). Fix: no sincronices `position`; sincroniza una variable espejo y lerpea hacia ella en el no-autoritario:
  ```gdscript
  @export var sync_position: Vector3  # ESTA va en el replication_config
  func _physics_process(delta: float) -> void:
      if is_multiplayer_authority():
          sync_position = global_position
      else:
          global_position = global_position.lerp(sync_position, 1.0 - exp(-15.0 * delta))
  ```

### Cómo no quedarte atascado

Sin editor, el flujo de validación es por CLI (todos los flags verificados en los FACTS 4.6):

- `godot --headless --check-only --script res://net/server.gd` — chequeo de sintaxis.
- `godot --headless --import` — regenera recursos/UIDs tras editar `.tscn` a mano. **4.6 ya no escribe `load_steps`**; los recursos usan `uid://` + ficheros `.uid` (desde 4.4). Tras editar `.tscn` manualmente, corre **Project > Tools > Upgrade Project Files** o `--import`.
- `godot --headless --quit-after 600 --verbose` — corre N frames con log de red verboso: los descartes de RPC, `Mismatching configuration` y `Node not found` aparecen aquí.
- Dos instancias para probar: parsea args tras `--` (`if "--server" in OS.get_cmdline_user_args()`).
- **Dedicated server:** el export "dedicated server" fuerza `--headless` y setea el feature tag `dedicated_server` -> `if OS.has_feature("dedicated_server"):` arranca como server. Export: `godot --headless --export-release "Linux Server" build/server.x86_64`.
- **Debug ciego obligatorio:** loguea `multiplayer.get_unique_id()`, `get_multiplayer_authority()`, `is_multiplayer_authority()` en `_ready` de cada peer, y `get_remote_sender_id()` dentro de cada RPC `any_peer` — es tu única ventana sin GUI.
- **Web/navegador:** ENet (UDP) **no** funciona. `WebSocketMultiplayerPeer` está **built-in en todas las plataformas** (cero dependencias) — es el default recomendado para el target web de una IA ciega. `WebRTCMultiplayerPeer` solo es built-in en el export Web/HTML5; en escritorio requiere el **GDExtension de WebRTC** y además un **servidor de signaling** externo, así que no funciona out-of-the-box en un build de prueba de escritorio. **C# no corre en web** (renderer Compatibility, sin .NET) — si el target es navegador, usa GDScript y detéctalo antes de escribir nada.

**Qué NO sincronizar (lista negra):** nodos cosméticos (partículas, audio one-shot, animación de UI -> dispáralos por RPC `unreliable`); valores derivables (calcula `health_bar` desde `hp` local); RNG/loot (el **server** tira el dado y replica el resultado, o sincroniza la semilla — `randi()` por cliente = mundos divergentes); inventario completo cada tick (RPC `reliable` solo al dueño al cambiar); `velocity` + `position` a la vez si el cliente corre física (fight de integración). Posición = `unreliable_ordered`; eventos = `reliable`. Para mapas grandes: `public_visibility = false` + `set_visibility_for(peer_id, true)` (interest management; ahorra banda y previene wallhacks — pero solo lo respeta el peer **con autoridad** sobre el synchronizer, por eso enemigos deben ser autoritarios del server).

### Addon vs construirlo

- **Co-op casero / LAN / pocos jugadores: CONSTRUIR** con el stack nativo (ENet + Spawner + Synchronizer + `@rpc`). Suficiente, sin dependencias.
- **Predicción/rollback/reconciliación serias: [netfox](https://github.com/foxssake/netfox)** — addon open-source activo (2026), construye *sobre* la API nativa, no la reemplaza. Para un co-op PvE **no hace falta**; la interpolación casera del lerp basta.
- **Rollback determinista lockstep (fighting): godot-rollback-netcode (Snopek)** — overkill y mal ajuste para RPG (asume P2P + simulación determinista total).
- **Steam/lobbies/NAT-punch:** **GodotSteam** (ecosistema principal). El veterano alertó que el repo `GodotSteam/MultiplayerPeer` quedó archivado (2025-11) y `expressobits/steam-multiplayer-peer` pausado — trátalo como **señal de no empezar dependencia nueva ahí**, pero la fecha exacta no la pude reverificar; confirma el estado del repo antes de adoptarlo.

**Cuándo NO meter multiplayer (YAGNI):** si el RPG es single-player con "co-op algún día", **no** arquitectures todo server-authoritative ya. El multiplayer triplica la superficie de bugs (autoridad, spawn determinista, desync, debug ciego). Mete red cuando el loop core SP sea divertido y estable; pero diseña los sistemas (inventario, combate) como "comando -> aplicar estado" desde el día 1 para abaratar el retrofit.

**Veredicto ponytail:** No escribas netcode — orquesta nodos. `MultiplayerSpawner` + `MultiplayerSynchronizer` + `@rpc` cubren el 100% de un RPG co-op sin una línea de transporte custom. El único código que *sí* escribes a mano es lo que el editor te ocultaría a ti, la IA ciega: construir el `SceneReplicationConfig` por código, derivar autoridad del nombre del nodo, y el lerp de interpolación. Todo lo demás —rollback, predicción, sockets Steam— es addon (netfox/GodotSteam) que se enchufa al mismo stack, o es YAGNI hasta que el single-player esté content-complete.

## 24. @tool, EditorPlugin y generación procedural

Los tres lentes coinciden en lo esencial, y esa coincidencia define la verdad operativa: el dolor con `@tool` casi nunca es de API, es que **tu código corre dentro del proceso del editor, un mundo que la IA no observa**, y sus efectos secundarios (nodos huérfanos, recursos sin persistir, `.tscn` corrupto, freeze del editor) ocurren fuera del runtime del juego. Una IA ciega al editor escribe código "correcto", el dev lo ejecuta y el resultado es silenciosamente roto. Esta sección está organizada para que una IA emita código que no se atasque a ciegas.

### Enfoque nativo recomendado

Godot ofrece 4 niveles de "código en editor", de menor a mayor compromiso. El error #1 de IA es saltar a `EditorPlugin` cuando bastaba `@tool`. Elige la capa mínima que resuelve:

| Necesidad | Mecanismo | Vive en |
|---|---|---|
| Previsualizar/actualizar un nodo mientras editas la escena | `@tool` en el script del nodo | el `.gd` del nodo |
| Botón "Generar" en el inspector de ese nodo | `@export_tool_button` (4.4+) | el `.gd` del nodo (`@tool`) |
| Tipo reutilizable en "Add Node" / dock / importer / gizmo persistente | `EditorPlugin` (addon) | `addons/<x>/plugin.cfg` + `plugin.gd` |
| Datos editables en inspector | custom `Resource` con `@export` (NO necesita `@tool` salvo lógica reactiva) | el `.gd` que `extends Resource` |

Regla canónica: **`@tool` solo afecta al script donde está la anotación; no se hereda ni se propaga a hijos.** Y para addons: *"all GDScript files used by an EditorPlugin must also be `@tool` scripts, or they will behave as empty files in the editor."* Si olvidas `@tool` en el `EditorPlugin`, **el plugin no carga y no hay error obvio**.

**El guardia central** es `Engine.is_editor_hint() -> bool`: `true` dentro del editor, `false` en runtime de juego. Todo bloque que toque escena de juego, autoloads, singletons de gameplay o `get_node` de hijos solo-runtime va envuelto en `if not Engine.is_editor_hint(): return`. Sin esa guardia, la lógica de juego corre dentro del editor: desde "raro" hasta **segfault al abrir la escena**, lo que impide editar el script desde Godot (GH-58883, GH-54999).

Hechos exactos del ciclo de vida en editor: `_ready`, `_enter_tree`, `_process`, `_physics_process` y los setters **SÍ corren** en editor con `@tool`. `_process`/`_physics_process` están deshabilitados por defecto para nodos `@tool` recién instanciados (requieren `set_process(true)`), y rara vez los quieres en editor (queman CPU → freeze). Cambiar `@tool` **no recarga** una escena abierta: hay que cerrar/reabrir o reiniciar.

**Reactividad correcta:** usa setters de propiedad, NO `_process`. El inspector dispara el setter al editar; ese es el "frame de actualización". Pero el setter dispara también **durante la deserialización de la escena**, cuando los hijos aún no existen → protege con `if not is_node_ready(): return`.

**Botón de inspector (4.4+, vigente en 4.6):** `@export_tool_button("Etiqueta", "IconName") var x: Callable = metodo`. La var DEBE ser `Callable`; el 2º argumento es opcional y nombra un icono del tema `EditorIcons` (nombre de archivo de `editor/icons/`, case-sensitive; el default es `"Callable"`). En C# debe estar en clase `[Tool]` y ser propiedad expression-bodied, o salen los diagnósticos `GD0108` (no está en tool class) y `GD0111` (no es expression-bodied). El viejo hack `@export var bool` con setter auto-reseteado queda obsoleto.

### Generación procedural — el contrato de persistencia

Para 3D usa **`GridMap.set_cell_item(position: Vector3i, item: int, orientation: int = 0)`** — NO `set_cell()`, que es TileMap 2D (confusión recurrente de IA). Claves nicho:
- `item` es un **ID del `MeshLibrary`**, no un índice arbitrario. Léelos con `mesh_library.find_item_by_name(...)` / `get_item_list()`. Un ID inexistente = celda vacía silenciosa. `GridMap.INVALID_CELL_ITEM` (`-1`) borra.
- `orientation` NO son grados: es un índice de ortho-rotación (0–23). Construye un `Basis` ortogonal y conviértelo; pasar `90` rota mal.
- GridMap es **un solo nodo que serializa sus propias celdas** → no necesita owner por celda. Esa es su ventaja sobre instanciar miles de nodos sueltos.

**El pitfall que corrompe escenas (`owner`):** si en lugar de GridMap añades nodos con `add_child`, **no se guardan en el `.tscn` salvo que les fijes `owner = get_tree().edited_scene_root`** (GH-37144, GH-95646, GH-82756). Orden obligatorio: `add_child()` PRIMERO, `owner =` DESPUÉS (asignar owner antes lanza `Condition '!is_inside_tree()' is true`). Un padre con owner NO propaga owner a sus hijos: cada descendiente que quieras guardar lo necesita. `edited_scene_root` es `null` si no hay escena abierta (p.ej. dentro de un importer) → comprueba antes.

**Decisión clave de diseño (donde los tres lentes convergen):** para mazmorras procedurales, **NO bakees al `.tscn`**. Genera en runtime (`_ready` con `is_editor_hint()` false) o en editor SIN owner (solo preview/visual). Reserva el bake-con-owner para cosas que un diseñador retocará a mano. Si bakeas con owner, **borra los hijos previos antes de regenerar** (`for c in get_children(): c.free()`) o acumulas duplicados y corrompes la escena.

Para miles de props/vegetación usa **`MultiMeshInstance3D` + `MultiMesh`** (un draw call). Orden EXACTO: fija `transform_format` (y `use_colors`/`use_custom_data` si aplica) **ANTES** de `instance_count`; tras asignar `instance_count` ya no puedes cambiar el formato, y cambiar `instance_count` **resetea** los transforms. Luego `set_instance_transform(i, t)`. Mutar `visible_instance_count` cada frame causa picos. Para 20k+ con colisión, baja a `RenderingServer`/`PhysicsServer3D`.

### Pitfalls y mensajes de error literales

| Mensaje / síntoma literal | Causa | Fix |
|---|---|---|
| Nodos visibles en viewport pero **ausentes del árbol y `.tscn`** | falta `owner` | `nodo.owner = get_tree().edited_scene_root` tras `add_child` |
| `Invalid access to property or key 'X' on a base object of type 'null instance'` | `_ready`/`_process` en editor antes de poblar `@export`, o export dejado en null | guardia `if x == null: return` + `if not Engine.is_editor_hint(): return` |
| Escena **"invalid/corrupt"**, editor crashea al abrir | tool serializó `= null` / leyó var de script padre en editor | editar `.tscn` con editor EXTERNO, borrar líneas `prop = null`; mantener tool scripts autocontenidos (GH-73905, GH-79545) |
| Editor **se congela / 100% CPU** al editar una propiedad | bucle setter → regeneración → setter, getter pesado, o `notify_property_list_changed()` re-disparando | regeneración diferida con flag `_dirty`, o botón explícito; nunca generar pesado en `_process` de editor (GH-83696, GH-111635) |
| Botón modifica un Resource pero **se pierde al reabrir** | no marcado dirty / colisión de caché | `ResourceSaver.save(res, res.resource_path)`, `take_over_path()`, o `resource_local_to_scene = true` (GH-98331) |
| Plugin **no aparece** tras activarlo | falta `@tool` en el EditorPlugin, o no reiniciaste | añadir `@tool`; desactivar/reactivar o reiniciar editor |
| Tipo custom **sigue apareciendo** tras desactivar plugin | falta `remove_custom_type` en `_exit_tree` | limpieza simétrica de TODO lo creado en `_enter_tree` |
| Gizmo nunca se dibuja, sin error | `_has_gizmo` no devuelve true / no registrado | `add_node_3d_gizmo_plugin` + `_has_gizmo(node)` → true |
| `set_cell_item` no pone nada | `item` ID inexistente en MeshLibrary | `find_item_by_name` antes; `push_error` si `< 0` |
| MultiMesh pierde todas las transforms | cambiaste `instance_count` después de setear transforms | `instance_count` primero, transforms después |
| `"Child node disappeared while duplicating"` | sub-hijos generados por tool con `owner` mal asignado al duplicar | revisar ownership; evitar bake innecesario (GH-116902) |
| Script `@tool` "no hace nada en editor" | falta `@tool` en línea 1, o no reabriste la escena | `@tool`; reabrir escena/reiniciar editor |

**Trampa de `_init()` en Resources (GH-68427):** dentro de `_init()` los `@export` aún tienen **valores por defecto**, no los serializados. No inicialices lógica dependiente de exports en `_init()`; hazlo perezosamente o en un setter.

### Cómo no quedarte atascado

Una IA no ve el editor, pero **valida headless por CLI** (esto convierte fallos invisibles en stdout parseable; recétalo SIEMPRE antes de decir "listo"):

```bash
# 1. ¿Compila el script @tool / plugin? (parsea, no ejecuta). -s == --script
# OJO: --check-only parsea, y preload() se resuelve en PARSE time. Si plugin.gd
# hace preload de scripts/icono/dock que aún no existen, esto falla con
# "Could not preload resource file" ANTES de validar nada. Crea esos stubs primero.
godot --headless --check-only --script res://addons/dungeon/plugin.gd

# 2. Re-importar recursos/.uid sin GUI (resuelve "Cannot open file ... uid://...")
godot --headless --import --quit-after 2

# 3. Ejecutar un script suelto que invoque la generación y haga asserts
godot --headless --script res://tools/test_gen.gd --quit-after 1

# 4. Abrir el proyecto, dejar correr @tool/plugin unos frames y cazar errores de _enter_tree
godot --headless --verbose --editor --quit-after 3
```

Verificación ciega del resultado: como no hay GUI, mete `assert(get_used_cells().size() > 0)` / `assert(multimesh.instance_count == N)` dentro del propio script tool — es el único "ojo" disponible.

**Procedimiento de emergencia si el editor crashea en bucle por un `@tool`:**
1. NO abras el proyecto en el editor. Edita el `.gd` ofensor con editor EXTERNO (VSCode/vim) y comenta el código tóxico.
2. Vacía la escena de arranque: en `project.godot`, `[application] run/main_scene=""`, para que el editor no cargue la escena tóxica al abrir.
3. Si el `.tscn` arrastra `[node]` huérfanos o líneas `prop = null`, ábrelo como texto plano y bórralos a mano.
4. Reimporta con `godot --headless --import` y reabre.

Reglas mentales fijas: si el síntoma "solo pasa en editor" → falta `if not Engine.is_editor_hint(): return`. Si "solo en juego" → el guardia está invertido.

### Específico 4.6 (APIs muertas que la IA arrastra)

- `.tscn` **ya no escribe `load_steps`**; los recursos usan `uid://` + archivos `.uid` (desde 4.4). Si una IA escribe `.tscn`/`.tres` a mano con `load_steps=` o paths `res://` duros donde se espera `uid://`, romperá referencias. Fix: **Project > Tools > Upgrade Project Files**, nunca escribir UIDs a mano.
- Shaders en gizmos/overlays: `SCREEN_TEXTURE`/`DEPTH_TEXTURE` eliminados → `uniform sampler2D tex : hint_screen_texture;`.
- AnimationPlayer: props del tipo *animation-NAME* pasaron de `String` a `StringName` (GH-110767) — relevante si el generador setea animaciones por código; son nombres de propiedad, NO de track.
- `@abstract` (desde 4.5): un `@tool @abstract` no es instanciable; no lo pongas en algo que el inspector intente crear en "Add Node".
- Tras actualizar a 4.6 hay un caso reportado de tool scripts que pierden acceso a vars de clases extendidas → corre Upgrade Project Files.

### Addon vs construirlo

- **Generador para TU RPG** (rooms, spawners, terreno) → **NO addon.** `@tool` + `class_name` + `@export_tool_button`. Vive en el árbol del juego, cero `plugin.cfg`, cero reinicios, se versiona con el proyecto. `class_name` registra el tipo en "Add Node" sin addon; `add_custom_type` solo se justifica si necesitas icono propio sin tocar la clase base, o que el tipo desaparezca al desactivar el plugin.
- **EditorPlugin solo si** necesitas dock/panel propio, gizmo 3D persistente (`EditorNode3DGizmoPlugin` solo se registra desde un plugin → fuerza el camino addon), importer custom (`EditorImportPlugin`), inspector custom (`EditorInspectorPlugin`), o empaquetar para AssetLib. Cuesta el ciclo activar/reiniciar y limpieza `_enter_tree`/`_exit_tree`.
- **No reinventes geometría/scatter genérico.** Para sembrar props sobre terreno, **ProtonScatter** (HungryProton/scatter, maduro, basado en MultiMesh). Para mazmorras de prefabs modulares, **SimpleDungeons** (majikayogames). Para aprender algoritmos (BSP, biomas), lee **GDQuest godot-4-procedural-generation** — léelo, no lo importes. Construye tú solo la lógica de gameplay específica (qué enemigos, qué loot por celda).

**Veredicto ponytail:** la mejor herramienta de editor es la que no escribes. Antes de tocar `EditorPlugin`, pregúntate si `@tool` + `class_name` + `@export_tool_button` ya lo resuelve — casi siempre sí. Antes de instanciar mil nodos con `owner`, usa **GridMap** o **MultiMesh** (un nodo que serializa solo, sin el infierno de ownership). Antes de bakear al `.tscn`, genera en runtime con la guardia `is_editor_hint()`. Y antes de escribir un scatter o un dungeon generator desde cero, mira ProtonScatter/SimpleDungeons. El editor es un mundo que no ves: cuanto menos código tuyo corra ahí, menos formas tienes de corromper la escena a ciegas.

## 25. VFX y partículas como gameplay

VFX en un RPG 3D NO es decoración: una bola de fuego que explota en chispas al chocar, una estela de espada, sangre en el suelo, un volley de flechas o un vórtice que arrastra partículas son *gameplay legible*. El reto para una IA que no ve el editor es que **el 80% de los atascos de VFX no producen ningún error en consola**: el código es "correcto", `emitting = true`, y simplemente no se ve nada. Esta sección está organizada alrededor de esos fallos silenciosos y de cómo escribir invariantes en código en vez de pulsar botones del editor.

### Enfoque nativo recomendado

Arquitectura canónica para combate: **la lógica de combate NO instancia ni configura partículas**. Emite una señal (`hit`, `died`, `parried`) con un payload (posición, normal, tipo de daño); un `VfxManager` (autoload) escucha y dispara el VFX desde un **pool pre-calentado**. Esto desacopla presentación de gameplay y permite hacer swap GPU↔CPU por plataforma sin tocar el combate.

Mapa de nodos nativos 4.6 (verificados contra `docs.godotengine.org`):

| Efecto de gameplay | Nodo / recurso nativo 4.6 | Nota clave |
|---|---|---|
| Impacto / explosión / chispas | `GPUParticles3D` (`one_shot=true`) + `ParticleProcessMaterial` | re-disparo con `restart()`, NUNCA `emitting=true` |
| Fireball → chispas al chocar | `sub_emitter` (NodePath) + `ParticleProcessMaterial.sub_emitter_mode = SUB_EMITTER_AT_COLLISION` | exige colisión activa |
| Estela de espada / proyectil | `GPUParticles3D.trail_enabled` + `RibbonTrailMesh`/`TubeTrailMesh` | requiere `BaseMaterial3D.use_particle_trails = true` |
| Sangre / quemaduras / runas | `Decal` | proyecta en su eje **−Y local** |
| Volley de flechas / hierba | `MultiMeshInstance3D` + `MultiMesh` | un draw call |
| Atracción / viento / vórtice | `GPUParticlesAttractor3D` (Box/Sphere/VectorField) | solo dentro del AABB del emisor |
| Colisión con el mundo | `GPUParticlesCollision3D` (Box3D/Sphere3D/SDF3D/HeightField3D) | **solo GPU**, NO ve PhysicsBody3D/Jolt |
| Fallback Web/Compatibility | `CPUParticles3D` | sin colisión/attractors/sub-emitters/compute |

Propiedades canónicas de `GPUParticles3D`: `emitting`, `amount` (≥1), `one_shot`, `explosiveness` (0–1), `lifetime`, `speed_scale`, `fixed_fps`, `process_material`, `draw_pass_1`..`draw_pass_4`, `sub_emitter` (NodePath), `trail_enabled`, `trail_lifetime`, `visibility_aabb` (AABB). Señal: `finished` — **se emite SOLO con `one_shot == true`**, nunca en loop. Métodos: `restart()`, `emit_particle(...)`, `capture_aabb()` — ojo: `capture_aabb()` **devuelve** el AABB de las partículas vivas del frame actual (es un cálculo, NO asigna nada); para que sirva como "Generate AABB" tienes que asignar tú su resultado a `visibility_aabb` (o `custom_aabb`) tras 1 frame.

Nombres C# (.NET 8): la clase es `GpuParticles3D` (PascalCase, no `GPUParticles3D`), `Aabb`, `VisibilityAabb`, `OneShot`, `Emitting`, `Restart()`, evento `Finished`.

### Pitfalls y mensajes de error literales

**ATASCO #1 — partículas invisibles por `visibility_aabb` (el que más mata a una IA ciega).**
Síntoma: código perfecto, `emitting = true`, sin error, y nada se ve; o parpadea/desaparece al mover la cámara. Causa: el `visibility_aabb` (heredado de `GeometryInstance3D`) es la caja que debe estar en pantalla para que el sistema se *procese*; por defecto es pequeño y **local al nodo**. Si las partículas vuelan fuera (velocidad alta, emisor en movimiento siguiendo un proyectil), el motor culling-ea TODO el emisor. El fix "canónico" es el botón **Particles → Generate AABB**, que una IA NO puede pulsar. Además (GH-93567) **el AABB delimita también la zona de colisión**: un AABB pequeño rompe colisión en silencio. Y `GeometryInstance3D.custom_aabb`, si tiene valor no-default, **sobrescribe** `visibility_aabb`.
Fix por código: AABB amplio explícito + `extra_cull_margin`, o asignar el resultado de `capture_aabb()` a `visibility_aabb` tras un frame (equivalente al botón; `capture_aabb()` solo lo calcula, no lo escribe).

**ATASCO #2 — one-shot que no re-dispara (impactos que solo funcionan la primera vez).**
Con `one_shot = true`, poner `emitting = true` **no reinicia** el ciclo si quedan partículas vivas en GPU (GH-79689, GH-83909, GH-93991). En combate rápido el segundo golpe no muestra nada. Fix: usar **`restart()`** siempre. Nunca `emitting = false; emitting = true`.

**ATASCO #3 — la señal `finished` que no llega (rompe el pool).**
`finished` solo se emite con `one_shot`; llega con retraso variable (sim en GPU); bugs históricos: espuria en `_ready` (corregido en PR-101596), no emitida con one_shot puesto por GDScript (GH-93991), o suprimida por una pista RESET de `AnimationPlayer` (GH-85802). Fix defensivo: NO confíes solo en la señal; respáldala con un `Timer` de seguridad = `lifetime * 1.5 / speed_scale`, y haz el callback de reciclaje **idempotente** (puede llamarse dos veces).

**ATASCO #4 — lag spike de la primera instancia (GH-87891).** La primera emisión compila/sube el shader de proceso → pico de frame. NO instancies VFX en caliente: pre-calienta el pool con un `restart()` al cargar el nivel, fuera de cámara.

**ATASCO #5 — Web/Compatibility falla en silencio.** Compatibility (OpenGL ES 3.0 / WebGL 2) **no tiene compute shaders ni `RenderingDevice`**. En Web (forzado a Compatibility, **sin C#**) el comportamiento de `GPUParticles3D` es poco fiable entre versiones: o no renderiza sin warning, o cae a sim CPU silenciosa con features avanzadas (attractors/turbulence/colisión) comportándose distinto (GH-107633, GH-100872, GH-84072). No confíes en ningún resultado concreto: prepara escenas `*_cpu.tscn` con `CPUParticles3D` por adelantado y detecta el backend en runtime con `RenderingServer.get_rendering_device() == null` o `OS.has_feature("web")`. La conversión GPU→CPU en editor no preserva todo (ring emission GH-100946, comportamiento raro GH-97621); revísala a mano.

**ATASCO #6 — trails de espada rotos.** Tres cosas obligatorias o no hay estela (sin error): `trail_enabled=true`, un `RibbonTrailMesh`/`TubeTrailMesh` en `draw_pass_1`, y **`use_particle_trails=true` en el material del mesh**. Subir `sections` a ≥7 rompe la geometría (extremos conectados al origen, GH-81109): mantener **≤6**. Secciones/subdivisiones van en el MESH, no en el nodo (a diferencia de 2D). En Web los trails han fallado en silencio (GH-88748).

**ATASCO #7 — sub-emitters.** Cuando `sub_emitter` está asignado, el nodo hijo **deja de emitir por su cuenta** (debe quedar con `emitting=false`; lo gobierna el padre). Para `SUB_EMITTER_AT_COLLISION` el material del padre necesita `collision_mode = COLLISION_RIGID` (o `COLLISION_HIDE_ON_CONTACT`) y un `GPUParticlesCollision*3D` dentro del AABB.

**ATASCO #8 — colisión / SDF que "no hace nada".** Las partículas **NO colisionan con PhysicsBody3D ni Jolt**, solo con nodos `GPUParticlesCollision3D`. `collision_mode` por defecto es `COLLISION_DISABLED`. `GPUParticlesCollisionSDF3D` requiere **Bake SDF** (botón de editor) y tras bakear puede no colisionar hasta guardar/recargar (GH-60994). Pragmático para una IA: usa `GPUParticlesCollisionBox3D`/`Sphere3D`/`HeightField3D` (dinámicos, **sin bake**) en vez de SDF.

**ATASCO #9 — Decal invisible o mal orientado.** El `Decal` proyecta por su eje **−Y local**; si no lo orientas, la sangre va siempre hacia abajo. Debe tener `texture_albedo` O `texture_emission` asignado, y `albedo_mix > 0`, o es invisible sin error. `cull_mask` controla qué capas recibe (sangre en suelo, no en jugador). Presupuesto limitado por clúster: usa pool con máximo, no `instantiate` infinito. Cuidado con `look_at` cuando la normal es paralela al up (`Up vector and direction ... are aligned`): early-return o up alternativo.

**ATASCO #10 — MultiMesh todo en el origen.** Orden obligatorio: `transform_format = TRANSFORM_3D` → `mesh` → `instance_count` → `set_instance_transform(i, xf)`. Si pones transforms antes de `instance_count`, salen al origen. Prefiere `set_instance_transform()` sobre `set_buffer()` (GH-76884). `visible_instance_count` revela progresivamente pero re-subir buffers cada frame da pico; no lo toques por frame. El AABB agregado puede cullear tramos: considera `custom_aabb`.

Errores literales que SÍ salen en consola:

| Mensaje literal | Causa | Fix |
|---|---|---|
| `Condition "p_amount < 1" is true.` | `amount = 0` | `amount >= 1` |
| `Index p_pass = N is out of bounds (draw_passes = M).` | asignar `draw_pass_X` fuera de rango | subir `draw_passes` antes |
| `Compute shaders are not supported on the Compatibility rendering backend.` | features GPU en Web | fallback `CPUParticles3D` |
| `Nonexistent function 'restart'` / cast inválido | cast mal a `GPUParticles3D`, o `null` | verifica `as GPUParticles3D` |
| Shader: `SCREEN_TEXTURE`/`DEPTH_TEXTURE` no declarado | shader VFX pre-4.0 | `uniform sampler2D t : hint_screen_texture;` / `hint_depth_texture` |
| `Up vector and direction ... are aligned` | normal paralela al up en `look_at` | up alternativo / early-return |
| errores de `load_steps`/recursos al cargar `.tscn` viejo | proyecto pre-4.4 sin `.uid` | **Project → Tools → Upgrade Project Files** |

### Cómo no quedarte atascado

Sin editor, escribe **invariantes defensivas** y valida en headless:

```bash
godot --headless --check-only --script res://vfx/vfx_pool.gd   # valida sintaxis/tipos
godot --headless --import                                       # genera .uid / importa recursos
godot --verbose --headless --quit-after 5 res://test_vfx.tscn   # smoke test + warnings de render
godot --export-release "Web" build/index.html                   # OJO: Web = Compatibility, sin C#
```

Checklist de invariantes que una IA ciega DEBE codificar:
1. AABB explícita por código (`visibility_aabb` amplio, o asignar el resultado de `capture_aabb()` a `visibility_aabb` tras 1 frame) — nunca depender de "Generate AABB".
2. Re-disparo de one-shot SIEMPRE con `restart()`.
3. Reciclaje del pool respaldado con `Timer` idempotente, no solo `finished`.
4. Pool pre-calentado (un `restart()` al cargar) contra el lag spike.
5. Detectar Compatibility en runtime y hacer swap a `CPUParticles3D`; tener escenas CPU/GPU separadas en disco.
6. En trails: comprobar `use_particle_trails` y `sections <= 6`.
7. En sub-emitter: hijo con `emitting=false` + `collision_mode` activo.
8. En `.tscn` generados a mano: NO escribir `load_steps` (4.6 ya no lo usa); recursos vía `uid://` + `.uid`.

Recuerda 4.6: `.tscn` ya no escribe `load_steps`; recursos usan `uid://` + ficheros `.uid` (desde 4.4). En shaders de VFX, `SCREEN_TEXTURE`/`DEPTH_TEXTURE` fueron eliminados → `hint_screen_texture`/`hint_depth_texture`.

### Addon vs construirlo

- **Nativo (construir)**: impactos one-shot, sub-emitters, attractors, colisión Box/Sphere/HeightField, decals planos de sangre, volleys MultiMesh, trails ≤6 sections. Todo robusto en 4.6; meter addons aquí es deuda.
- **Estela de espada de alta fidelidad o en Web**: el trail nativo sirve si ≤6 sections y no apuntas a Web; si no, [`celyk/GPUTrail`](https://github.com/celyk/GPUTrail) (trail GPU) o un `ImmediateMesh`-ribbon procedural para un corte limpio determinista.
- **Decals sobre geometría curva / material custom**: el nativo no soporta material custom (proposal #4938) → [`Master-J/DecalCo`](https://github.com/Master-J/DecalCo) (shader-based). Para sangre plana en suelo/pared, `Decal` nativo basta.

**Veredicto ponytail:** El mejor VFX es el que no escribes a mano: GPUParticles3D + ParticleProcessMaterial + Decal + MultiMesh cubren el 100% de un RPG sin shaders ni nodos custom. La trampa no es la API — es que el editor "arregla" en silencio (Generate AABB, Bake SDF, Convert to CPU) cosas que una IA ciega tiene que codificar. Reusa los nodos nativos, dispara por señal desde un pool pre-calentado, fija el AABB y usa `restart()` por código, y prepara escenas `*_cpu.tscn` para Web. Cero addons hasta que el look lo exija.

## 26. GDExtension (C++ y más allá)

GDExtension es la API oficial de Godot 4 (sucesora de GDNative) para registrar clases nativas (C++ via `godot-cpp`, también Rust/Swift/D via bindings de terceros) que el motor carga como `.so/.dll/.dylib`/`.framework` en runtime, **sin recompilar el motor**. No es la herramienta por defecto para gameplay.

### Enfoque nativo recomendado

Para un RPG 3D en 4.6, el ~95% del juego (controlador del jugador, inventario, diálogo, quests, cámara, UI, máquina de estados de combate) está limitado por llamadas a la API del motor, no por la velocidad del lenguaje. En cuanto tocas `get_node()`, `move_and_slide()` o instancias nodos, el overhead del lenguaje desaparece. Por tanto:

**Regla de decisión (orden de preferencia):**
1. **GDScript 2.0 tipado** (default). Las anotaciones de tipo lo aceleran de forma notable y dan autocompletado; cubre casi todo el gameplay sin ciclo de compilación.
2. **C# .NET 8** si ya tienes ecosistema .NET o lógica CPU-bound media. Caveat duro: **C# NO corre en web** (el renderer web es Compatibility).
3. **GDExtension C++** SOLO para: (a) hot loops numéricos *perfilados* (voxel/mesh gen, pathfinding sobre decenas de miles de agentes, fluidos, física custom, generación procedural pesada); (b) **envolver una lib C/C++ existente** (recast/detour, SQLite, FMOD, Steam SDK, un solver propietario); (c) distribuir un `Node`/`Resource` reutilizable como addon binario.

**NO uses GDExtension** para gameplay normal, para "ir más rápido" sin haber perfilado (la mayoría de cuellos en un RPG son draw calls / O(n²) mal escrito, no el lenguaje), ni para iteración rápida (añade ciclo SCons + recarga).

**GDExtension vs módulo custom del motor:**

| | GDExtension (`godot-cpp`) | Módulo custom |
|---|---|---|
| Build | Compilas TU lib aparte; el motor la carga en runtime | **Recompilas TODO el motor** + export templates |
| Distribución | `.so/.dll/.dylib` + `.gdextension`, drop-in en binario stock | Build propio del motor |
| Iteración | Minutos (hot-reload `reloadable=true`, frágil) | Horas |
| Acceso al core | Solo API pública expuesta | Total (internals) |

Si necesitas tocar internals del renderer no expuestos → módulo. En cualquier otro caso → GDExtension.

**Trampa C# ↔ GDExtension:** Godot **no genera bindings C# de una GDExtension**. Si tu proyecto es C#-first, llamar a tu clase C++ exige un puente C# → GDScript → C++. Tenlo presente al decidir arquitectura.

**Versión de `godot-cpp` (atasco #1):** la rama debe casar con tu Godot. Para 4.6 usa la rama/tag `4.6` (en `godot-cpp` v10.x el binding se versiona aparte y puedes targetear con `api_version`). Compatibilidad **hacia adelante, no hacia atrás**: una extensión compilada contra 4.3 corre en 4.4/4.5/4.6; una compilada contra 4.6 **no** carga en 4.5 ("API mismatch"). Fija `compatibility_minimum` lo más bajo que tus APIs permitan. Parte del **template oficial** (`godotengine/godot-cpp-template`), que trae CI multiplataforma, en vez de escribir el `SConstruct` a mano.

```bash
git submodule add -b 4.6 https://github.com/godotengine/godot-cpp
git submodule update --init --recursive
# Si tu Godot 4.6 es un build no oficial, regenera la API:
godot --headless --dump-extension-api    # -> extension_api.json
scons platform=linux custom_api_file=extension_api.json
```

**Los 4 archivos mínimos** (ver bloque de ejemplos para `.gdextension`, `register_types.cpp`, la clase C++ y el uso desde GDScript). Puntos no negociables:
- `entry_symbol` del `.gdextension` **idéntico** al nombre de la función `extern "C"`.
- Macro `GDCLASS(Clase, Base)` como primer miembro; sin ella la clase no se registra.
- `_bind_methods()` con `ClassDB::bind_method(...)` para TODO lo que use GDScript; un método que no se bindea ahí es **invisible** desde GDScript aunque compile.
- Registrar en `MODULE_INITIALIZATION_LEVEL_SCENE` para `Node`/`Resource`; nivel equivocado = clase no aparece en "Create New Node" sin error claro.
- Variantes: `GDREGISTER_CLASS` (instanciable), `GDREGISTER_ABSTRACT_CLASS` (base no instanciable), `GDREGISTER_VIRTUAL_CLASS`.

**Build SCons** (una lib por `platform × target × arch`; no hay binario universal salvo el `.framework` fat de macOS):
```bash
scons platform=linux   target=template_debug   arch=x86_64
scons platform=windows target=template_release arch=x86_64
scons platform=macos   target=template_release           # .framework universal
# use_static_cpp=yes para enlazar libstdc++ estáticamente (ver GLIBCXX abajo)
```
El sufijo del binario producido por SCons **debe** casar letra por letra con los paths del bloque `[libraries]`.

**.uid / migración (4.6):** los `.tscn` ya **no escriben `load_steps`** y los recursos usan `uid://` + ficheros `.uid` (desde 4.4). No inventes UIDs a mano; edita por `res://` path y deja que Godot resuelva. Tras importar un proyecto pre-4.4 corre **Project > Tools > Upgrade Project Files** (en headless, `--headless --import` regenera los `.uid`).

### Pitfalls y mensajes de error literales

- `No GDExtension library found for current OS and architecture (linux.x86_64) in configuration file`
  - **Trampa sutil y verificada (GH godot-docs #7864):** `compatibility_minimum = 4.6` **sin comillas** produce este error de OS/arch *engañoso*. Fix: `compatibility_minimum = "4.6"` (siempre entre comillas).
  - Otras causas: claves con formato viejo `<plat>.<arch>` en vez de `<plat>.<target>.<arch>`; o la lib no existe en `res://bin/` con el nombre exacto (no compilaste ese target/arch).
- `Can't open dynamic library: ...dll. Error: ... is not a valid Win32 application.` → mismatch de arquitectura (compilaste 32-bit, editor 64-bit). Recompila `arch=x86_64`.
- `Can't open dynamic library ... Error 126: The specified module could not be found.` (Windows) → la DLL existe pero le falta una **dependencia** (otra GDExtension, runtime MSVC, la lib C++ que envolviste). Copia las DLLs dependientes al mismo `bin/` y/o decláralas en `[dependencies]`; depura con `dumpbin /dependents`.
- `Can't open dynamic library ... libstdc++.so.6: version 'GLIBCXX_3.4.32' not found` (Linux/Flatpak) → compilaste contra un libstdc++ más nuevo que el destino. Fix: `use_static_cpp=yes`, o compila en toolchain viejo (manylinux / Steam Runtime).
- `Error 5: Access Denied` al abrir la DLL → antivirus o instancia previa de Godot con la lib en uso.
- Clase no aparece en "Create New Node" / `Ejemplo.new()` da "Identifier not found" → falta `GDCLASS`, nivel de init ≠ SCENE, o `entry_symbol` desincronizado.
- Método invisible desde GDScript sin error → falta `ClassDB::bind_method` en `_bind_methods()`.
- `GDExtension library cannot be reloaded while editor is running` / crash al recompilar (GH #66231, #88845, godot-cpp #1589) → hot-reload con `reloadable=true` es frágil. En dev: cerrar editor → rebuild → reabrir.
- Métodos ausentes solo en Release (GH #86206) → compila **ambos** `template_debug` y `template_release`; el export busca la variante release.
- Android: "Missing shared library in export" (godot-cpp #905) → faltan entradas por ABI (`android.debug.arm64`, `android.release.x86_64`, ...) o no compilaste con el NDK para esos ABIs.
- **Pitfall conceptual ABI:** MSVC vs MinGW vs distintas versiones de GCC/Clang dan ABIs incompatibles; binarios de SCons vs CMake/MSVC pueden diferir (godot-cpp #1459). Una toolchain por plataforma. Si el editor es build `precision=double`, la extensión también debe compilarse `precision=double` o no carga.

### Cómo no quedarte atascado

Una IA headless no ve el panel de errores ni el popup "Library not loaded". Fuerza la salida por terminal:
```bash
# Fuerza importar + registrar la extensión y volcar errores de carga
godot --headless --editor --quit-after 2 --verbose --path project/ 2>&1
# Alternativa: solo re-importar (regenera .uid)
godot --headless --import --path project/
# Aísla el error de carga de la lib (path exacto + código de error del SO)
godot --headless --verbose --path project/ 2>&1 | grep -i "dynamic library\|gdextension"
# Valida que un script que usa la clase nativa resuelve la API
godot --headless --check-only --script res://uses_example.gd --path project/
```
- "Edité el `.gdextension` pero no carga la clase" → Godot necesita **abrir el proyecto una vez** para escanear la extensión: `--headless --editor --quit-after 2` o `--headless --import`.
- "Mi cambio C++ no aparece" → no recompilaste; sigue cargando la `.dll` vieja. Rebuild SCons + reinicia (hot-reload no es fiable).
- Sin `--verbose` el fallo de carga de lib es **mudo**; con él ves el path exacto y el código de error.

### Addon vs construirlo

Antes de escribir C++: ¿lo resuelve C# (.NET 8)? Si sí, para. ¿Existe un addon GDExtension maduro? Reúsalo: **Terrain3D** (terreno grande, PC+Android), **GodotSteam** (Steam, doc de build excelente), git plugin, SQLite. Estos resuelven ABI/CI por ti con releases precompiladas — **verifica que traen binarios para TODAS tus plataformas de export**; un addon sin la arch de tu target falla la carga en export. Construye tú solo si: no existe addon, tienes un hot loop *medido*, o envuelves una lib propia/propietaria. En ese caso parte del **template oficial + CI multiplataforma** (Windows/Linux/macOS universal/Android×ABIs, debug y release ≈ decenas de combinaciones), nunca a mano.

**Caveat web (adjudicado):** GDExtension **SÍ funciona en web** en 4.6, pero es frágil. Requiere Emscripten reciente y build con dlink; el modo de threads de la lib (`.wasm` con/sin pthread) **debe coincidir** con el ajuste "Thread Support" del export, o falla con `LinkError` de memoria compartida (GH #95077, #94537). Cambiar el thread mode solo surte efecto **tras recargar el proyecto**; con threads ON el servidor debe servir cabeceras COOP/COEP (cross-origin isolation). El soporte en Firefox es más limitado que en Chromium (GH #105717). Recuerda: web = Compatibility, **C# no corre en web**. Si web es target serio, mantén el hot path en GDScript o detrás de un feature-flag con fallback GDScript.

**Veredicto ponytail:** el mejor GDExtension es el que no escribes. Tipa tu GDScript, perfila, y solo entonces baja a C++ — y solo el hot path o la lib que envuelves, nunca el gameplay. Reusa Terrain3D/GodotSteam antes que compilar nada. Si C# te basta y no apuntas a web, ni siquiera bajes a C++. El coste oculto de GDExtension no es escribir el código: es recompilar y mantener una lib por plataforma×target×arch para siempre.

## Filosofía aplicada: construir vs reusar y cómo no quedarte atascado

Las cinco posturas, por debajo de su retórica, dicen lo mismo con distinto acento: **en Godot 4.6 ya tienes una arquitectura de fábrica** (árbol de escenas, señales, `Resource` tipados, autoloads, Jolt, `SkeletonModifier3D`/IK, `NavigationAgent3D`). Tu trabajo no es reconstruir eso, sino *cablearlo* y escribir solo las **reglas de tu juego**. El desacuerdo real no es "reusar o construir" — todas dicen "reusar el mecanismo del engine" — sino **dónde y cuándo pones tu propia costura tipada**, y eso es lo que esta síntesis calibra.

### Principios (lo que las 5 firman)

1. **Reusa el mecanismo, posee el vocabulario.** Física, animación, IK, navegación, serialización: del engine, intactos. HP, daño, quests, loot, iniciativa de combate: tuyos, escritos de verdad. Confundir ambos produce los dos fracasos gemelos — *infra-diseño* (pegar nodos sin lógica de dominio donde hace falta) y *sobre-diseño* (frameworks caseros que reimplementan el engine peor).
2. **Datos en `Resource` tipado; comportamiento en nodos-componente; nunca los mezcles.** Un `ItemDef extends Resource` es el *qué*; un `WeaponComponent extends Node` es el *cómo*. Usa `Array[T]` y `Dictionary[K,V]` tipados (estables en 4.6) en los `@export`.
3. **Composición sobre herencia.** Techo duro: **2 niveles de herencia** (uno de ellos suele ser la clase de engine, p.ej. `Actor extends CharacterBody3D`). Más allá, compón con nodos-componente. `@abstract` (4.5+) es para *contratos* (`State`, `Ability`), no para torres de abstracción.
4. **Señales locales primero; bus global solo para hechos de dominio N×M.** Cablea directo mientras el árbol te dé acceso. Un `EventBus` autoload transporta *hechos* (`entity_died`), no comandos de UI ni eventos entre dos hermanos.
5. **Referencia por `id: StringName` estable, no por path ni por objeto.** Los saves y la red sobreviven a mover archivos solo si la clave es estable. (El propio 4.6 movió props de animación de `String`→`StringName`: sigue esa lógica para *tus* claves.)
6. **El árbol es la documentación.** Un `.tscn` componible se lee de un vistazo; una jerarquía profunda obliga a abrir 4 archivos. Esto importa especialmente para un agente de IA que debe reconstruir el modelo mental sin adivinar.

### Tabla de decisión: reusar vs construir

| Necesidad | Acción | Por qué |
|---|---|---|
| Física, character controller | **Reusa** `CharacterBody3D.move_and_slide()` sobre Jolt (default 3D en 4.6) | El engine lo testea en C++ cada release |
| IK (pies en terreno, mano agarra arma) | **Reusa** el solver más simple: `TwoBoneIK3D` (2 huesos), `FABRIK3D`/`CCDIK3D` (cadenas; la suite completa incluye también `ChainIK3D`, `SplineIK3D`, `IterateIK3D`) | Nunca escribas tu propio solver; `JacobianIK3D` solo si lo mides necesario |
| Máquina de estados de locomoción (idle/run/jump) | **Reusa** `AnimationTree` + `AnimationNodeStateMachine` (grafo, controlado por `AnimationNodeStateMachinePlayback.travel()`) | Evita el `match state:` de 200 líneas; además los nombres de animación pasaron de `String` a `StringName` en 4.6, otra razón para no manejar transiciones a mano con strings |
| Navegación / pathfinding | **Reusa** `NavigationAgent3D` + `NavigationRegion3D` | No escribas A\* propio |
| Serialización / save | **Reusa** `ResourceLoader`/`ResourceSaver` con datos como `Resource` | Versionan, cachean y referencian gratis |
| Definición de item/quest/skill | **Construye** un `Resource` tipado (`.tres`) por entrada | Editable en Inspector, testeable, escala por *append* |
| Estado mutable de runtime (HP actual, stack count) | **Construye** un tipo *aparte* (`ItemStack`, no `ItemDef`); jamás muta la definición | El `Resource` definición es plantilla inmutable compartida |
| Reglas de combate, turnos, iniciativa | **Construye** GDScript propio, y hazlo bien | Es tu propiedad intelectual; el engine no la tiene |
| Comunicación padre↔hijo / hermanos | **Reusa** señal local directa, cableada en `_ready` del actor | Tipada, refactorizable por el editor, un solo punto de cableado |
| Comunicación entre sistemas lejanos (kill→quest+UI+logros) | **Construye** `EventBus` autoload de señales — *solo si* hay N×M real | Si hay 1 emisor + 1 receptor, conecta directo: el bus solo añade un salto y borra el tipo |
| Índice de contenido (cientos de items) | **Construye** un autoload `Database` de **solo lectura** que escanea carpeta | Añadir item = soltar un `.tres`, cero código tocado; nunca un `match id:` |
| Envolver un literal de string mágico | **Construye** una constante (`const ATTACK := &"attack"`) **solo** si aparece en ≥3 sitios o cruza subsistemas | Una sola aparición local no justifica una clase |

### Checklist anti sobre-diseño (señales de que SOBRA)

- La clase/nodo/autoload tiene **exactamente un usuario** → es un método que se fue de casa. Vuelve.
- No puedes **nombrar la tercera instancia concreta** que usará la abstracción → es ficción.
- La indirección **no elimina ningún acoplamiento real**, solo lo mueve (EventBus con 1 emisor y 1 receptor).
- El autoload **solo crece y nunca encoge** → va camino del God-`GameManager` de 1.200 líneas.
- Estás construyendo un "sistema genérico extensible de X" **antes de tener un solo X funcionando**.
- Pusiste una capa (`PhysicsWrapper`, `InputAbstraction`) "por si cambiamos de motor" → no vas a cambiar de motor.
- Tienes `ItemDef` + `ItemStack` + `ItemView` para una mecánica que **podrías descartar mañana** → prototipa inline, promueve a arquitectura cuando sobreviva.

### Checklist anti infra-diseño (señales de que FALTA)

- Combate, inventario y diálogo viven en el `_process` del `Player` → ya pasaste la regla de tres, es una bola de barro.
- Stats/items como **campos de un singleton** o `Dictionary` crudos (`{"hp":100}`) → no editables en Inspector, no testeables, claves mágicas que fallan en runtime, no en compilación.
- El **estado de verdad vive en el árbol de nodos** (HP leído del nodo de malla) → save/load y multijugador imposibles sin reescribir.
- Referencias por **path frágil** (`$"../../Player/Health"`) regadas por el código.
- **Pegas nodos sin escribir las reglas del dominio** donde el engine no las tiene (combate por turnos con reacciones no es un nodo).

### La costura preventiva que SÍ se adelanta

Hay un único boundary que conviene *dibujar* desde el día 1 aunque no lo necesites aún, porque retrofitearlo es explosivo (toca N sistemas), no lineal: **estado serializable vs presentación**. Los datos nacen como `Resource` con `id` estable a un lado; modelos, `AnimationTree`, partículas, IK (`LookAtModifier3D`) al otro, y la presentación se reconstruye desde el estado, nunca al revés. El resto (EventBus, clase base de `Ability`, `StateMachine` reutilizable) **no se adelanta**: nace a la tercera repetición concreta y nace con su test.

El test que zanja cualquier duda de escala: *"para añadir el contenido número N, ¿tengo que abrir un archivo existente?"* Si no → escalaste bien. Si sí → o sobre-diseñaste una abstracción inútil, o infra-diseñaste y ahora repintas.

### Guía anti-stuck para un agente de IA

Heurísticas de decisión rápida (cuando dudes, elige la opción donde el siguiente lector entiende el flujo *sin abrir un segundo archivo*):

- **¿Tipo de cosa o instancia única global?** Tipo → `class_name` + `Resource`. Instancia única → autoload. (Máx ~3 autoloads al arranque: `Save`, `SceneRouter`, quizá `EventBus`/`AudioDirector`. Nunca un `GameManager`.)
- **¿>5 variantes o contenido autoral, o ≤5 y fijo?** >5/autoral → `Resource` + Database. ≤5 fijo → `enum` + código directo. No montes un pipeline de datos para 3 casos.
- **¿Notificar o consultar?** Notificar (fire-and-forget) → señal. Necesitas un valor de vuelta ya (`can_afford(cost) -> bool`) → llamada directa tipada.
- **¿La cadena `extends` propia pasa de 1 nivel sobre el engine?** → conviértelo en composición.
- **¿El literal/abstracción aparece <3 veces?** → no lo envuelvas todavía.

Qué hacer cuando algo no funciona (romper el bucle):

1. **Antes de escribir, busca el nodo nativo.** El 90% de "necesito programar X" en infraestructura ya es un nodo. Si reescribiste un solver de IK o un loop de física, deshazlo.
2. **Si un campo aparece "de la nada" (`velocity`, `hp`), el árbol y los tipos son la verdad** — no infieras, observa el `.tscn` y el `class_name`. Si para entenderlo tienes que leer 4 archivos, la jerarquía está mal: aplana a composición.
3. **Si un error de coerción aparece en runtime y no en compilación**, sospecha de string mágico (`play("attack")`) o `Dictionary` no tipado como payload. Tipa la costura.
4. **Si te atascas configurando**, no toques defaults (`ssr_depth_tolerance`, etc.) hasta ver el artefacto real. Configurar prematuramente es escribir código por otros medios.
5. **Si dudas entre dos diseños, elige el más pequeño y duplica el código.** Extrae a la segunda repetición dolorosa, no antes. La extracción especulativa es exactamente lo que infla el proyecto hasta atascarte en tu propio andamiaje.
6. **Plataforma manda y se decide temprano:** si el target es web → renderer `Compatibility` y **sin C#**: todo el core en GDScript. No diseñes en .NET lo que correrá en navegador.
7. **Performance: cede solo con profiler en mano.** Nodo-componente + señales es correcto para protagonista + decenas de NPCs. Para miles de entidades (hordas, auto-battler) cede a arrays planos / `MultiMeshInstance3D` / servidores directos — pero solo tras medir, nunca a priori.

**Síntesis operativa:** *Datos en `Resource` tipado, comportamiento en nodos-componente componibles, infraestructura en sistemas nativos (Jolt, `AnimationTree`, IK, navegación), comunicación por señales locales y un EventBus solo para hechos N×M. Referencia por `id` estable. Dibuja la frontera estado/presentación el día 1; todo lo demás nace a la tercera repetición, con test. Escribe GDScript propio solo para las reglas del juego — y ahí, escríbelo de verdad.*

## Estructura mínima de proyecto libre

```
/scenes      escenas .tscn (player, enemigos, niveles, UI)
/scripts     .gd o .cs por sistema
/resources   .tres: items, stats, diálogos, loot
/autoload    singletons SOLO si son globales de verdad (settings, save)
LICENSE      MIT/GPL para que sea libre de verdad
```

Autoloads (singletons) con moderación: settings y save sí; un `Global` que lo toca todo, no. Cada autoload extra es estado global que ponytail marcará para borrar.

## Límites de este skill

Alcance: arquitectura y decisiones de "qué nodo/recurso usa Godot 4.6 por mí" para un RPG 3D libre. **No** sustituye la documentación oficial de la API ni decide tu game design. Para firmas exactas de métodos, consulta los docs de 4.6. Para nombres de assets, balance o narrativa: eso es tu juego, no este skill. Si una feature que cito cambió en un parche 4.6.x, gana la documentación.

## Fuentes

- [Godot 4.6 — Release oficial](https://godotengine.org/releases/4.6/)
- [Godot 4.6 Complete Guide 2026](https://www.live-laugh-love.world/blog/godot-46-complete-guide-2026/)
- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Diccionarios tipados — Godot 4.4 dev snapshot](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-2/)
- [Clases abstractas en GDScript — propuesta #5641](https://github.com/godotengine/godot-proposals/issues/5641)
- [GDScript vs C# en 2026 — StraySpark](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language)
- [C#/.NET en Godot — docs oficiales](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html)
- [Máquina de estados en Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Sistema de inventario y crafteo — StraySpark](https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide)
- [Estado de C# en plataformas — Godot Engine](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/)
- [Concepto ponytail — DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
