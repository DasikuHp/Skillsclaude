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



> **Escalera ponytail:** rung 4 (InputMap/Input) · **net propio:** remapeo runtime + detección de dispositivo; el motor da el resto.
