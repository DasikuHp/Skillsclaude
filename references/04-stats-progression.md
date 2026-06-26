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



> **Escalera ponytail:** rung 4 (Resource + Curve) · **net propio:** un Resource Stats con señales; sin StatSystem framework.
