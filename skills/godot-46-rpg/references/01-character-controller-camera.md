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



> **Escalera ponytail:** rung 4 (nodo nativo) · **net propio:** CharacterBody3D + SpringArm3D; solo escribes la locomoción (~40 líneas).
