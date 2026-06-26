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



> **Escalera ponytail:** rung 4 (nodo nativo) · **net propio:** NavigationAgent3D + FSM en GDScript; behavior-tree (LimboAI) solo a escala. # TECHO: FSM se vuelve inmanejable con muchos estados → UPGRADE a behavior tree.
