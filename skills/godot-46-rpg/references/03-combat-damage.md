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



> **Escalera ponytail:** rung 4 (nodo + Resource) · **net propio:** Area3D (hit/hurtbox) + Resource DamageInfo; sin CombatManager.
