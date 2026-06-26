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



> **Escalera ponytail:** rung 4 (nodo nativo) · **net propio:** AnimationTree + AnimationNodeStateMachine + IKModifier3D; 0 arquitectura, solo config.
