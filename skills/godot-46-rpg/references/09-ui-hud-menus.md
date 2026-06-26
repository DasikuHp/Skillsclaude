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



> **Escalera ponytail:** rung 4 (Control + Theme) · **net propio:** reaccionas a señales de stats; sin framework de UI.
