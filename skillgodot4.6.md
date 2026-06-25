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

La clave del diseño es **desacoplar "hacia dónde miro" de "cuánto se acerca la cámara"**: el `CameraPivot` (un simple `Node3D`) recibe la rotación del ratón, y la `SpringArm3D` solo gestiona la distancia/colisión hacia atrás. El `SpringArm3D` "castea" un rayo (o una forma) por su eje −Z y reposiciona a sus hijos en el punto de colisión, con un `margin` opcional ([SpringArm3D docs](https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html)).

**APIs nativas (verificadas en docs 4.6):**

- `CharacterBody3D.velocity: Vector3` — propiedad; `move_and_slide()` la lee y la actualiza. En 4.x `move_and_slide()` **no acepta argumento** de velocidad (a diferencia de Godot 3) ([CharacterBody3D docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)).
- `move_and_slide() -> bool`, `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()`.
- `get_gravity() -> Vector3` — lee la gravedad del área/ProjectSettings como vector; preferido sobre leer manualmente el escalar `physics/3d/default_gravity` ([CharacterBody2D/3D guide](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)).
- `floor_snap_length: float` (default 0.1) — pega el cuerpo al suelo tras `move_and_slide()`; subir a ~0.3–1.0 m en terreno irregular o bajadas.
- `floor_max_angle: float` (default 0.785398 rad ≈ 45°), `floor_stop_on_slope: bool` (default `true`), `motion_mode` (`MOTION_MODE_GROUNDED` por defecto).
- `SpringArm3D.spring_length`, `margin`, `collision_mask`, `shape: Shape3D` (si se asigna hace shape-cast en lugar de raycast), y `add_excluded_object(rid: RID)` para excluir el propio collider del Player ([SpringArm3D docs](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html)).
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
- **Breaking 4.5→4.6**: los nombres de pista de `AnimationPlayer` pasaron de `String` a `StringName`. Tras actualizar a 4.6 hay que **recompilar el ensamblado C#**; el código que pasaba literales `string` a APIs de animación puede necesitar `StringName` explícito.

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
- **`move_and_slide()` sin argumento**: en 4.x lee de la propiedad `velocity`; si nunca la asignas, el cuerpo no se mueve ([CharacterBody3D guide](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)).
- **SpringArm colapsando**: sin `add_excluded_object(get_rid())` el brazo detecta el propio cuerpo del Player y la cámara se pega a él. Alternativa: poner al Player en una capa que la `collision_mask` del brazo no incluya.
- **`floor_snap_length` corto**: el personaje "despega" en cimas de pendientes y pierde contacto en bajadas/escalones pequeños (godot#71993). Subir a ~0.3–1.0 m; con 0 el snapping se desactiva.
- **Deslizar parado en pendientes**: si `floor_max_angle` es menor que el ángulo de la rampa, Godot la trata como pared y desliza. Asegura `floor_stop_on_slope=true` y un ángulo que cubra tus rampas ([Bugnet](https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot)).
- **Step-up de escaleras NO automático**: limitación abierta del motor (godot-proposals#2751); con Jolt por defecto en 4.6 tampoco hay step-up integrado en `move_and_slide`. Soluciones: shape-cast manual de step-up o un addon.
- **Acumulación de `event.relative`**: si la acumulación de input está desactivada pueden llegar varios `InputEventMouseMotion` por frame; suma (no asignes) deltas ([Yo Soy Freeman](https://yosoyfreeman.github.io/article/godot/tutorial/achieving-better-mouse-input-in-godot-4-the-perfect-camera-controller/)).
- **Recompilar C# tras 4.6**: cambio `String`→`StringName` en pistas de animación.

### Addon vs construirlo

- **Rueda propio** el movimiento de `CharacterBody3D`: son ~40 líneas y en un RPG querrás control total de slopes, snap, estados y locomoción. Los nodos nativos cubren el 90%.
- **Usa Phantom Camera** ([ramokz](https://github.com/ramokz/phantom-camera)) si necesitas múltiples cámaras, transiciones cinemáticas o lock-on a objetivos (típico de RPG de acción) — estilo Cinemachine, ahorra mucho frente a gestionar SpringArm a mano.
- **Para solo la cámara** (sin lógica cinemática), `SpringArm3D` nativo + pivote es suficiente; no necesitas addon.
- Como **arranque/prototipo** para 4.6: *Real Controller* ([asset 4494](https://godotengine.org/asset-library/asset/4494)) o *Third Person Controller* ([asset 3934](https://godotengine.org/asset-library/asset/3934), soporta 4.4/4.5/4.6); el repo MIT de GDQuest ([gdquest-demos](https://github.com/gdquest-demos/godot-4-3d-third-person-controller)) es excelente referencia (se escribió para 4.x, los patrones son idénticos en 4.6 — verifica nombres de pista de animación tras importar por el cambio String→StringName).

**Veredicto ponytail:** NO construyas tu propio sistema de cámara con raycasts ni una FSM de cámara — `SpringArm3D` + un `Node3D` pivote ya hacen colisión, margen y shape-cast nativamente; reutiliza Phantom Camera solo si el RPG necesita lock-on/cinemáticas. Lo único que escribes a mano es la locomoción de `CharacterBody3D` (~40 líneas), porque ahí sí quieres control total de slopes y estados.

## 2. Animación / AnimationTree / IK

La animación de personaje en un RPG 3D de Godot 4.6 se resuelve con una pila nativa de cuatro capas: banco de clips (`AnimationPlayer`), control y blending (`AnimationTree` con `AnimationNodeStateMachine` + `AnimationNodeBlendSpace2D`), y post-pose por hueso (`Skeleton3D` con la familia `SkeletonModifier3D` / `IKModifier3D`). No hace falta escribir un sistema de animación propio: todo lo que sigue es reutilización de nodos de primera clase. La verdad incómoda del dossier — que `TwoBoneIK3D` usaría propiedades planas tipo `target_node` — quedó **refutada al verificar la clase**: la API real es por índice (`set_target_node(index, path)`) sobre un `setting_count`, porque un mismo modificador puede resolver varias cadenas IK a la vez ([TwoBoneIK3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/TwoBoneIK3D.xml)).

### Enfoque nativo recomendado

**Datos — `AnimationPlayer`.** Banco de clips. En 4.6 los nombres de track y de animación son `StringName` (breaking change 4.5→4.6; recompilar el ensamblado C#). El track del hueso raíz se marca como root motion vía la propiedad `root_motion_track` del `AnimationMixer` ([class_animationplayer 4.6](https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html)).

**Control — `AnimationTree`** (hereda de `AnimationMixer` en 4.6, [AnimationTree.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationTree.xml)). `tree_root` apunta a un `AnimationNodeStateMachine` (o `AnimationNodeBlendTree`); `anim_player` (NodePath) al `AnimationPlayer`; `advance_expression_base_node` al nodo base para expresiones de transición. El root motion se lee por frame con métodos heredados de `AnimationMixer`: `get_root_motion_position() -> Vector3` (delta de posición, NO velocidad), `get_root_motion_rotation() -> Quaternion`, `get_root_motion_rotation_accumulator() -> Quaternion` y `get_root_motion_position_accumulator() -> Vector3` ([AnimationMixer.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationMixer.xml)).

**Máquina de estados — `AnimationNodeStateMachine` + `AnimationNodeStateMachinePlayback`.** El playback se obtiene con `tree.get("parameters/playback")` y se castea a `AnimationNodeStateMachinePlayback`. Firmas verificadas: `travel(to_node: StringName, reset_on_teleport := true)`, `start(node: StringName, reset := true)`, `stop()`, `get_current_node() -> StringName`, `get_travel_path() -> StringName[]`, `is_playing() -> bool`. `travel()` recorre el grafo de transiciones con A\* ([AnimationNodeStateMachinePlayback.xml](https://github.com/godotengine/godot/blob/master/doc/classes/AnimationNodeStateMachinePlayback.xml), [kidscancode recipe](https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html)).

**Locomoción — `AnimationNodeBlendSpace2D`.** Mapea un `Vector2` (p. ej. x = strafe, y = forward/back) a clips ubicados en puntos 2D que Godot triangula. Se controla con `tree.set("parameters/<Nodo>/blend_position", Vector2(x, y))`.

**Post-pose / IK — `Skeleton3D` + `SkeletonModifier3D` / `IKModifier3D`.** Los modificadores son hijos del `Skeleton3D` y corren **después** de evaluar el `AnimationTree`, en el orden del árbol de escena. `IKModifier3D` (hereda de `SkeletonModifier3D`) es la base de la suite IK; su única propiedad propia relevante es `mutable_bone_axes` (bool, default `true`) y gestiona N cadenas vía `setting_count` / `set_setting_count(n)` / `clear_settings()` ([IKModifier3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/IKModifier3D.xml), [artículo oficial IK 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)). Los 7 solvers: `TwoBoneIK3D` y `SplineIK3D` (deterministas, predecibles — ideales para pies/brazos); `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` (iterativos, convergen — para cadenas largas como colas/columnas); más `ChainIK3D` e `IterateIK3D` (base de los iterativos — `FABRIK3D` hereda de `IterateIK3D`). Para mirar (cabeza/ojos): `LookAtModifier3D` (4.4), con `bone_name`/`bone`, `target_node`, `forward_axis`, `use_angle_limitation`, `origin_from` ([LookAtModifier3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/LookAtModifier3D.xml)). Para colgar armas/props a un hueso: `BoneAttachment3D` (`bone_name` / `bone_idx`), también hijo del `Skeleton3D`.

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
	# rotación absoluta vía accumulator (evita el bug incremental #93821/#95688)
	var rot := tree.get_root_motion_rotation_accumulator()
	var pos: Vector3 = tree.get_root_motion_position()  # delta local, no velocidad
	transform.basis = Basis(rot) * transform.basis.orthonormalized()
	var motion := transform.basis * pos
	velocity = motion / delta if delta > 0.0 else Vector3.ZERO

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

    // En 4.6 los nombres de parámetro/track son StringName. String y StringName
    // NO autoconvierten (#64171); cachéalos. Tras migrar a 4.6 hay que RECOMPILAR
    // el ensamblado C# por el cambio String -> StringName en los track names.
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
        Quaternion rot = _tree.GetRootMotionRotationAccumulator(); // struct por valor
        Vector3 pos = _tree.GetRootMotionPosition();               // delta local
        Transform = Transform with { Basis = new Basis(rot) * Transform.Basis.Orthonormalized() };
        Vector3 motion = Transform.Basis * pos;
        Velocity = delta > 0f ? motion / delta : Vector3.Zero;
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

- `AnimationPlayer` — banco de clips; tracks ahora `StringName`.
- `AnimationTree` : `AnimationMixer` — `tree_root`, `anim_player`, `advance_expression_base_node`, `callback_mode_process`, `active`; root motion vía `root_motion_track` / `get_root_motion_*()`.
- `AnimationNodeStateMachine` / `AnimationNodeStateMachinePlayback` — `travel`, `start`, `get_current_node`, `get_travel_path`, `is_playing`.
- `AnimationNodeBlendSpace2D` — blending 2D triangulado; `parameters/<Nodo>/blend_position`.
- `Skeleton3D` — esqueleto; contenedor de modificadores.
- `IKModifier3D` : `SkeletonModifier3D` — base IK; `setting_count`, `mutable_bone_axes`, `clear_settings()`, `reset()`.
- `TwoBoneIK3D` : `IKModifier3D` — determinista; API por índice (`set_root_bone_name`, `set_middle_bone_name`, `set_end_bone_name`, `set_target_node`, `set_pole_node`).
- `FABRIK3D` : `IterateIK3D` / `CCDIK3D` / `JacobianIK3D` — iterativos.
- `SplineIK3D`, `ChainIK3D`, `IterateIK3D` — cadenas.
- `LookAtModifier3D` : `SkeletonModifier3D` — `bone_name`, `target_node`, `forward_axis`, `use_angle_limitation`.
- `BoneAttachment3D` — anclar props/armas a un hueso.

### Pitfalls

- **`StringName` en track/parameter names (breaking 4.5→4.6)**: recompilar C#; `String` != `StringName`, no autoconvierten ([#64171](https://github.com/godotengine/godot/issues/64171)). Comparaciones literales pueden fallar en silencio.
- **API IK por índice, no plana**: `TwoBoneIK3D` NO tiene `target_node` directo; usa `set_target_node(index, path)` sobre `setting_count`. Configura las cadenas en el editor o con `set_setting_count()` antes de los setters ([TwoBoneIK3D.xml](https://github.com/godotengine/godot/blob/master/doc/classes/TwoBoneIK3D.xml)).
- **Root motion + rotación**: la acumulación incremental con fading rompe la locomoción ([#93821](https://github.com/godotengine/godot/issues/93821), [#95688](https://github.com/godotengine/godot/issues/95688)). Usar `get_root_motion_rotation_accumulator()` y aplicar rotación absoluta.
- **`get_root_motion_position()` es delta, no velocidad**: orientarlo por el `basis` y dividir por `delta` antes de `move_and_slide()`. Considera `root_motion_local`.
- **Orden de modificadores**: IK/LookAt corren tras el `AnimationTree` y en orden del árbol; un `LookAtModifier3D` antes de un `TwoBoneIK3D` puede ser sobrescrito. `active` togglea cada uno.
- **`travel()` a sub-estado anidado**: bug histórico al viajar directo a un estado dentro de un SubStateMachine ([#62576](https://github.com/godotengine/godot/issues/62576)); workaround: travel al sub-SM y luego al estado interno.
- **IK iterativos no deterministas**: FABRIK/CCD/Jacobian pueden temblar (jitter); preferir `TwoBoneIK3D` para extremidades de personaje ([foro IK 4.6](https://forum.godotengine.org/t/which-godot-4-6-ik-solver-is-best-for-player-pose-tracking-fabrik-vs-twobone-vs-ccd/129191)).
- **Retargeting Mixamo**: clips con rest pose T/A correcta + `SkeletonProfileHumanoid` + `BoneMap`; fuentes sin rest pose válida producen poses raras ([#89244](https://github.com/godotengine/godot/issues/89244)).

### Addon vs construirlo

- **IK**: NO usar addon. Es nativo y de primera clase en 4.6 (suite `IKModifier3D`). La escena de muestra [Inverse Kinematics Example](https://store.godotengine.org/asset/andicraft/inverse-kinematics-example/) sirve solo como referencia de setup, no como dependencia.
- **State machines de animación**: `AnimationNodeStateMachine` nativo basta para locomoción/combate. Para el **cerebro de IA** (separado de la animación) considerar [LimboAI](https://github.com/godotengine/awesome-godot) (behavior trees + HSM con editor y debugger) o XSM. Regla: animación = `AnimationTree` nativo; IA = LimboAI.
- **Retargeting Mixamo**: nativo (`BoneMap` + `SkeletonProfileHumanoid`) funciona; el plugin [RaidTheory/Godot-Mixamo-Animation-Retargeter](https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter) automatiza el bone map para flujos masivos de clips — innecesario para pocos.

**Veredicto ponytail:** No construyas un sistema de animación, un blend tree ni un solver IK propios, ni un wrapper de "propiedades planas" sobre `TwoBoneIK3D`. Reutiliza `AnimationTree` + `AnimationNodeStateMachine` + `AnimationNodeBlendSpace2D` para control y blending, root motion nativo (`get_root_motion_*` con el accumulator), y la suite `IKModifier3D` (TwoBoneIK3D determinista para pies/brazos, LookAtModifier3D para la cabeza, FABRIK3D/CCDIK3D para colas) como hijos del `Skeleton3D`. Para IA, delega en LimboAI en vez de mezclar gameplay con animación.

## 3. Combate y daño

El combate de un RPG 3D en Godot 4.6 se resuelve casi por completo con tres recursos que la engine ya te da: `Area3D` para la detección de golpes, un `Resource` propio para los datos del daño, y `Timer` para i-frames y ventanas de ataque. No necesitas un motor de combate; necesitas conectar señales y dejar que las capas de colisión hagan el filtrado.

### Enfoque nativo recomendado

El patrón canónico (confirmado en docs oficiales, GDQuest y el addon de cluttered-code) es **Hitbox/Hurtbox sobre `Area3D`**, NO sobre `body_entered` de cuerpos físicos. Esto desacopla la detección de golpes del movimiento físico y se comporta igual en Forward+, Mobile y Compatibility ([GDQuest](https://www.gdquest.com/library/hitbox_hurtbox_godot4/)).

Reparto de responsabilidades (terminología GDQuest):

- **Hitbox** = la parte que *inflige* daño (arma, puño, proyectil). `Area3D` + `CollisionShape3D` hijo.
- **Hurtbox** = la parte que *recibe* daño (cuerpo del personaje). También `Area3D` + `CollisionShape3D`.

**Deja que las capas de colisión hagan el chequeo de tipos.** Si configuras bien `collision_layer`/`collision_mask`, solo un lado emite la señal y te ahorras `is`/casts en runtime, evitando dobles disparos y fuego amigo sin código ([dredyson](https://dredyson.com/advanced-area3d-hitbox-optimization-how-i-mastered-duplicate-hit-prevention-with-professional-collision-detection-techniques-complete-configuration-guide-for-godot-4-6-2/)):

- Hitbox del jugador: `collision_layer = capa "player_hitbox"`, `collision_mask = 0`.
- Hurtbox del enemigo: `collision_layer = capa "enemy_hurtbox"`, `collision_mask = "player_hitbox"`.
- Así solo la hurtbox emite `area_entered`; el hitbox ni escucha.

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
    var victim: Node = area.owner
    if victim == null:
        return
    var id := victim.get_instance_id()
    if _already_hit.has(id):          # un golpe por víctima por swing
        return
    _already_hit[id] = true
    if victim.has_method("take_damage"):
        victim.take_damage(damage_info)
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
- **Breaking 4.5→4.6:** los nombres de pista de `AnimationPlayer` pasaron de `String` a `StringName`. Si tu combate dispara hitboxes vía Call Method Track, **recompila el proyecto C#** o esas llamadas pueden romperse silenciosamente.
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

- **Deshabilita el `CollisionShape3D`, NO el `Area3D`.** Al desactivar `CollisionShape3D.disabled` la engine lo retira de los tests de solapamiento; si tocas `monitorable`/`monitoring` del Area, el nodo sigue en el mundo físico y solo deja de reportar (con deferimiento que crea race conditions) ([dredyson](https://dredyson.com/fix-duplicate-hit-detection-in-godot-4-6-2-area3d-hurt-hit-boxes-a-beginners-step-by-step-guide-to-resolving-race-conditions-collisionshape3d-vs-area3d-disabling-and-blacklist-dictionary-workarou/)).
- **Doble golpe (race condition).** Un hitbox que solapa varias hurtboxes en el mismo frame dispara `area_entered` por cada una; con hurtboxes por hueso, un puñetazo genera 4-6 señales. Solución: diccionario blacklist por swing, **limpiado en `start_attack()` antes de habilitar el shape**, con clave = `instance_id` de la víctima.
- **Jolt (default en 4.6) + Area3D — issues abiertos reales:** [#106482](https://github.com/godotengine/godot/issues/106482) reporta gran impacto de rendimiento con muchos `Area3D` solapados **aunque `monitorable = false`**, porque `JoltArea3D` fija el motion_type del sensor a kinematic (hay [PR #106490](https://github.com/godotengine/godot/pull/106490) de mihe en curso); [#118047](https://github.com/godotengine/godot/issues/118047) confirma lag con Area3D solapadas en Jolt; [#109721](https://github.com/godotengine/godot/issues/109721) reporta `body_exited` inconsistente tras reposicionar CharacterBody3D. Implicación RPG: **no dejes decenas de hurtboxes activas permanentemente**; desactiva las de enemigos fuera de pantalla. Si ves comportamiento raro, prueba "Godot Physics" para aislar el bug ([#88441](https://github.com/godotengine/godot/issues/88441)).
- **`get_overlapping_areas()/bodies()` van un frame desfasados** respecto a las señales y no se actualizan en el instante del `area_exited` ([proposal #8610](https://github.com/godotengine/godot-proposals/issues/8610)). No los uses para decidir el golpe en el frame del exit.
- **`monitoring` debe ser `true`** en el lado que escucha o `area_entered` nunca dispara (frecuente en C#).
- **`emit_signal()` está desaconsejado** en 4.x; usa `mi_senal.emit(...)`.

### Addon vs construirlo

**Addon mantenido (4.x):** *Health, HitBoxes, HurtBoxes and HitScans* de cluttered-code, MIT, 2D y 3D. Provee `HurtBox3D`, `HitBox3D`, `HitScan3D` (extiende `RayCast3D`) y un componente `Health`. Versión actual v5.0.3 (mayo 2026); en v5 los componentes base llevan prefijo "Basic" y se añadieron variantes con múltiples tipos de daño y modificadores — **migra a v4.4.0 antes de saltar a v5.0.0** por los cambios de nombres ([GitHub](https://github.com/cluttered-code/godot-health-hitbox-hurtbox), [Asset Library](https://godotengine.org/asset-library/asset/3636)).

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
- **`Dictionary[StringName, float]`** (diccionario tipado 4.6) para resistencias: claves `StringName` (rápidas de comparar, casan con nombres de tipo de daño), valores `float` ([class_dictionary](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)).
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

Reglas para que un `Resource` aparezca en "New Resource" y se serialice: clase **`partial`**, archivo propio con nombre = nombre de clase (case-sensitive), hereda de `Resource`, marcada `[GlobalClass]` ([C# global classes](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_global_classes.html)).

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
- Los parámetros de `[Signal]` y los miembros `[Export]` deben ser **Variant-compatibles** (marshalling C#/C++); el diagnóstico GD0202 salta si no lo son ([c_sharp_differences](https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/c_sharp/c_sharp_differences.rst)).
- Conectar señales con `+=` **no se autodesconecta**: o haces `-=` manual, o usas `Connect()` (que se limpia al liberar el nodo). Emitir señales custom externas dio errores documentados en Issue [#82268](https://github.com/godotengine/godot/issues/82268); prefiere `EmitSignal(SignalName.X, ...)`.
- **Breaking 4.5→4.6**: los nombres de tracks de `AnimationPlayer` pasaron de `String` a `StringName`. Si disparas animaciones de level-up/daño por nombre de track, **recompila el proyecto C#** o fallará el marshalling.

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

**UI = drag-and-drop nativo de `Control`.** Los tres métodos virtuales (firmas confirmadas en la [doc de Control](https://docs.godotengine.org/en/stable/classes/class_control.html)):

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

# id -> cantidad para apilables; los no apilables van a slots aparte.
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
# Los Resource se comparten por referencia: duplicate(true) = deep copy.
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
        var dict = data.As<Dictionary>();
        if (dict == null || !dict.ContainsKey("item"))
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
- **Gotcha 4.5→4.6:** los nombres de pista de `AnimationPlayer` pasaron de `String` a `StringName`. Si tu UI de inventario dispara animaciones por nombre, **recompila el ensamblado C#** tras actualizar — el cambio de tipo no es transparente para código ya compilado.

### Nodos/clases 4.6

- **`Resource`** + **`@export`** / **`[GlobalClass]`** — items como datos (`.tres`).
- **`Dictionary[StringName, int]`** — stacking y modifiers tipados ([doc 4.6](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)).
- **`Control`** + `_get_drag_data` / `_can_drop_data` / `_drop_data` / `set_drag_preview` — drag-and-drop nativo ([doc Control](https://docs.godotengine.org/en/stable/classes/class_control.html)).
- **`GridContainer`** / **`PanelContainer`** / **`TextureRect`** — la rejilla de slots y el icono; sin código de layout custom.
- **`ResourceLoader.load`** / `preload` / **`DirAccess`** — cargar la BD de items.
- **`signal`** / `[Signal] delegate` — `changed` para refrescar UI sin polling.

### Pitfalls

- **Resources compartidos por defecto (la trampa #1).** 50 cofres apuntando al mismo `.tres` comparten estado. Si el item tiene estado mutable, `duplicate(true)` (deep) — `duplicate()` simple no copia subrecursos anidados ([issue #37222](https://github.com/godotengine/godot/issues/37222), [forum](https://forum.godotengine.org/t/duplicate-not-making-a-unique-copy-of-my-custom-resource/46404)). Pero si el item es inmutable (espada genérica), **NO dupliques**: guarda la referencia + cantidad y ya.
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
    return not expr.has_execute_failed() and bool(result)
```

Quests con el mismo patrón, actualizadas por señal:

```gdscript
# quest.gd / quest_objective.gd
class_name QuestObjective extends Resource
enum Kind { KILL, COLLECT, TALK, REACH }
@export var kind: Kind = Kind.KILL
@export var target: StringName
@export var required: int = 1
@export var progress: int = 0
func is_done() -> bool: return progress >= required

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

**Gotcha 4.6 (String → StringName)**: en 4.6 los nombres de tracks de `AnimationPlayer` pasaron de `String` a `StringName`. Si tus diálogos disparan animaciones por nombre (`player.Play("talk")`), **recompila el ensamblado C#** tras subir de 4.5; pasa los nombres como `StringName` (`new StringName("talk")` o el literal `&"talk"` en GDScript) para evitar conversiones implícitas costosas. Para conectar señales a métodos GDScript snake_case desde C#, sigue usando `Connect("line_displayed", Callable.From(...))`; para señales entre código C#, prefiere siempre `+=` o `EmitSignal(SignalName.X, ...)` y evita `Callable.Bind`/lambdas con args, históricamente conflictivos ([issue #71895](https://github.com/godotengine/godot/issues/71895)).

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

> Nota de versión: `NavigationServer3D` sigue marcado como **experimental** en los docs de 4.6 ("may be changed or removed in future versions") y no recibió rediseño en 4.6 respecto a 4.4/4.5. La API de alto nivel (`NavigationAgent3D`) es estable en la práctica. 4.6.1 trajo fixes de navegación: `map_get_closest_point_normal` ahora devuelve un valor normalizado y hornear navmesh de colliders de `GridMap` es más rápido ([release notes 4.6.1](https://godotengine.org/article/maintenance-release-godot-4-6-1/)).

### Enfoque nativo recomendado

La escena de un enemigo navegable se arma con estos nodos, ninguno custom:

- **`NavigationRegion3D`** — contiene un recurso **`NavigationMesh`**. Se hornea con el botón "Bake NavMesh" del editor o por código con `bake_navigation_mesh()`. Colecciona geometría de hijos según `geometry/parsed_geometry_type`. Ajusta `Agents/Radius` y `Cell Size` del `NavigationMesh` si los agentes se atascan en paredes ([intro nav 3D](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_introduction_3d.html), [navmeshes](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationmeshes.html)).
- **`CharacterBody3D`** — raíz del enemigo. Es el nodo correcto para un personaje cinemático con gravedad manual y `move_and_slide()`.
- **`NavigationAgent3D`** (hijo del `CharacterBody3D`) — el cerebro de pathfinding. API clave verificada en docs stable ([NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html)):
  - `target_position: Vector3` — destino. Tras asignarlo hay que llamar `get_next_path_position()` **una vez por frame físico** para que el agente actualice su estado interno de path.
  - `get_next_path_position() -> Vector3` — siguiente waypoint.
  - `is_navigation_finished() -> bool` — guarda principal antes de mover.
  - `is_target_reachable()`, `distance_to_target()`.
  - `set_velocity(velocity: Vector3)` — **solo para avoidance**.
  - Señales: `velocity_computed(safe_velocity: Vector3)`, `target_reached`, `navigation_finished`, `waypoint_reached`.
  - Avoidance: `avoidance_enabled`, `radius`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`, `max_speed`.
- **`Timer`** — repathing periódico (recalcular `target_position` cada ~0.2–0.5 s, no cada frame). Reusar el nodo `Timer` evita escribir un acumulador a mano.
- **`NavigationObstacle3D`** (opcional) — obstáculos dinámicos. **Limitación documentada:** solo afecta el *avoidance local*, NO replanifica el path global; los agentes no rodean obstáculos móviles ([obstacles](https://docs.godotengine.org/en/stable/classes/class_navigationobstacle3d.html)).
- **`NavigationServer3D`** (capa baja, sin nodo agente) — `map_get_path(map, origin, target, optimize, navigation_layers=1) -> PackedVector3Array`. Útil para previsualizar rutas. Devuelve array **vacío** si no hay ruta: guardar siempre con `if not path.is_empty()` ([NavigationServer3D](https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html)).

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
	if target and _agent.is_target_reachable():
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

# Tabla de transiciones legibles para depurar (Dictionary tipado 4.6).
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
	if _agent.is_navigation_finished():
		return
	var next: Vector3 = _agent.get_next_path_position()
	var desired: Vector3 = global_position.direction_to(next) * speed
	desired.y = velocity.y - gravity * delta       # gravedad ANTES del avoidance
	_agent.set_velocity(desired)                   # NO mover aquí; esperar señal

func _on_safe_velocity(safe_velocity: Vector3) -> void:
	# Bug #108252: el avoidance descarta la Y al terminar la nav. Reaplicar.
	velocity = safe_velocity
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
        if (Target != null && _agent.IsTargetReachable())
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

**Gotcha 4.6 obligatorio en C#:** el cambio de track names de `String` a `StringName` en `AnimationPlayer` exige **recompilar el ensamblado C#** al migrar de 4.5; los nombres de tracks/animaciones que pasabas como `string` siguen funcionando, pero hay que recompilar para que el binding resuelva bien.

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

Clases 4.6 implicadas (sin cambios de API respecto a 4.5; las páginas `class_*` son `stable`/`latest`):

- **`ConfigFile`** — settings. `set_value(section, key, value)`, `get_value(section, key, default)` (¡pasa siempre el 3.º argumento para no romper al añadir keys en updates!), `save("user://settings.cfg")`, `load(path)`. Variantes cifradas: `save_encrypted_pass` / `load_encrypted_pass` ([docs ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html)).
- **`FileAccess`** — E/S de bajo nivel. `FileAccess.open(path, FileAccess.WRITE|READ)` devuelve `null` si falla (chequea `FileAccess.get_open_error()`). `store_string()` / `get_as_text()` para texto; `store_var(value, full_objects=false)` / `get_var(allow_objects=false)` para binario seguro. `open_encrypted_with_pass(path, mode, pass)` para cifrado casual ([docs FileAccess](https://docs.godotengine.org/en/latest/classes/class_fileaccess.html)).
- **`JSON`** — serialización portable. Estático: `JSON.stringify(data, "\t")` (pretty-print) y `JSON.parse_string(text)` (devuelve `null` si error). Con instancia para diagnóstico: `var j := JSON.new(); j.parse(text)` + `j.get_error_message()` / `j.get_error_line()` ([docs JSON](https://docs.godotengine.org/en/stable/classes/class_json.html)).
- **`ResourceSaver` / `ResourceLoader`** — solo para datos de autoría. `ResourceSaver.save(res, "user://x.tres")`; `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)` — usa `CACHE_MODE_IGNORE` o el cache (`CACHE_MODE_REUSE`, default) te devuelve la instancia vieja al recargar un slot ([docs ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html), [GDQuest](https://www.gdquest.com/library/save_game_godot4/)).

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

Idiomático: `partial class : Node`, `[Export]`, `[Signal]` con delegados `EventHandler`. La comunidad usa `System.Text.Json` con `FileAccess` para la E/S, no el `JSON` de Godot ([Mouillard](https://medium.com/@romain.mouillard.fr/lightweight-saving-loading-system-in-godot-4-with-c-a-practical-guide-2cb6cbd2faa3), [Aceade](https://aceade.net/2025/01/12/parsing-arbitrary-json-in-godot-net/)):

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

    public SaveData LoadGame(int slot)
    {
        string path = SlotPath(slot);
        if (!FileAccess.FileExists(path))
            return null;
        using var f = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (f is null)
            return null;
        var data = JsonSerializer.Deserialize<SaveData>(f.GetAsText());
        EmitSignal(SignalName.GameLoaded, slot);
        return data;
    }
}
```

**Gotcha C# 4.6 (breaking 4.5→4.6):** los nombres de tracks de `AnimationPlayer` pasaron de `String` a `StringName`. **Recompila el proyecto C#** tras actualizar a 4.6, y revisa cualquier dato de animación serializado por nombre. Recuerda además que las señales solo transportan tipos primitivos / builtin de Godot / `GodotObject`, lo cual condiciona cómo estructuras tus DTOs de save.

### Nodos/clases 4.6

- `ConfigFile` (Resource) — settings.
- `FileAccess` (RefCounted) — E/S, `store_var`/`get_var`, cifrado por password.
- `JSON` (RefCounted) — serialización portable.
- `ResourceSaver` / `ResourceLoader` (singletons) — solo datos de autoría; `CACHE_MODE_IGNORE` al recargar.
- `DirAccess` — crear `user://saves/` con `make_dir_recursive_absolute`.
- Un `Node` autoload como `SaveManager` con `signal` para notificar la UI.

### Pitfalls

- **Ejecución de código al cargar `.tres`/`.res`:** un Resource puede embeber un script que corre al cargar. Si cargas un save que el jugador editó, eso es RCE. Por eso el progreso va en JSON plano, no en Resources ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). Si **debes** cargar Resources como saves, usa el *Godot Safe Resource Loader* (drop-in que verifica que el `.tres` no contiene código).
- **`store_var`/`get_var` son seguros por defecto** (`full_objects=false` / `allow_objects=false`): binario sin serialización de objetos. Solo se vuelve peligroso si activas `full_objects=true` — ahí reintroduces el mismo riesgo que los Resources ([docs FileAccess](https://docs.godotengine.org/en/latest/classes/class_fileaccess.html)).
- **JSON convierte todo número a `float`:** un `int` guardado se relee como `1.0`. Castea con `int()`. Tipos Godot (`Vector3`, `Color`) no son JSON-nativos → serialízalos como arrays/strings.
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

**Barras de vida/recurso.** Tanto `ProgressBar` como `TextureProgressBar` derivan de `Range` ([ProgressBar docs](https://docs.godotengine.org/en/stable/classes/class_progressbar.html), [TextureProgressBar docs](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html)). Propiedades de `Range`: `value`, `min_value`, `max_value`, `step`, `page`, `ratio` (normalizado 0–1, solo lectura), `exp_edit`, `rounded`; señal `value_changed(value: float)`. `TextureProgressBar` añade hasta tres texturas — `texture_under`, `texture_progress`, `texture_over` — más `fill_mode` (`FILL_LEFT_TO_RIGHT`, `FILL_BOTTOM_TO_TOP`, `FILL_CLOCKWISE`…), `tint_progress`, `nine_patch_stretch` y `stretch_margin_*`. Usa `TextureProgressBar` cuando quieres arte; `ProgressBar` cuando basta un rectángulo del tema.

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

**Gotcha 4.5→4.6 en C#:** los nombres de pista de `AnimationPlayer` pasaron de `String` a `StringName`, así que **recompila** el proyecto C# tras actualizar; cualquier código que pasara nombres de pista como `string` literal sigue funcionando por conversión implícita, pero hay que reconstruir los assemblies. Usa `StringName` (`&"..."` en GDScript) para nombres de override/variation y acciones de input.

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

- **Tween + pausa:** un `Tween` independiente se detiene cuando el árbol está en pausa aunque el nodo destino sea `PROCESS_MODE_ALWAYS` ([GH #81994](https://github.com/godotengine/godot/issues/81994)). Para fades del menú de pausa, crea el tween desde un nodo en `PROCESS_MODE_ALWAYS`; los tweens ligados a un nodo heredan su process mode.
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

1. **Cambio de escena completo — `SceneTree`.** `SceneTree.change_scene_to_packed(packed: PackedScene) -> Error` cuando ya tienes el `PackedScene` cargado (resultado de carga threaded), y `SceneTree.change_scene_to_file(path: String) -> Error` como atajo síncrono que carga el `.tscn` y bloquea. Accedes vía `get_tree()` desde cualquier `Node`, o `Engine.get_main_loop() as SceneTree`. **Gotcha verificado en docs**: ambos liberan la escena saliente de forma diferida (al final del frame), así que justo tras la llamada `get_tree().current_scene` puede ser `null`; no asumas cambio inmediato ([class_scenetree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html), [docs issue #8868](https://github.com/godotengine/godot-docs/issues/8868)).

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
                float p = _progress.Count > 0 ? (float)_progress[0] : 0f;
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
