## Notas de adjudicación (dónde discreparon las 3 lentes y cómo lo resolví)

Las tres lentes (docs, veterano, escéptico) fueron notablemente consistentes en lo fundamental. Discrepancias y resoluciones:

1. **Serialización del save (la única discrepancia real de criterio).**
   - *docs* y *escéptico*: guardar los `InputEvent` directamente en `ConfigFile` (son `Resource`), o `var_to_str`/`GD.VarToStr`.
   - *veterano*: prefiere JSON manual (tipo + campos primitivos) por portabilidad entre refactors y diffeabilidad en git (su Pitfall #14).
   - **Adjudicación:** ambos son correctos; no hay una API "mala". Por el principio ponytail ("el mejor código es el que no escribes") prioricé el camino nativo — `ConfigFile` con `InputEvent` Resources — como recomendación de partida, y dejé el JSON manual como upgrade opcional explícitamente acotado a proyectos que evolucionan mucho. Verificable en docs que `ConfigFile.set_value` acepta Resources, así que no es dudoso.

2. **`var_to_str` vs guardar el Resource directo.** *docs* usa `var_to_str(events)` + `str_to_var`; *veterano*/*escéptico* guardan el `Array[InputEvent]` directo en `ConfigFile`. Ambos funcionan. Elegí guardar el `Array` directo en el ejemplo principal (más simple, menos pasos), que es lo que hacen 2 de 3 lentes. Mantengo la mención de que `var_to_str` es la vía oficial subyacente.

3. **`Input.action_release` (claim solo del escéptico).** Lo VERIFIQUÉ por WebSearch contra la doc de la clase Input: existe, firma `void action_release(action: String)`, descripción oficial: "If the specified action is already pressed, this will release it." Lo mantengo como fix del binding pegado (GH-63734). No era invento.

4. **`DisplayServer.keyboard_get_keycode_from_physical` vs `OS.get_keycode_string(event.get_physical_keycode_with_modifiers())`.** *escéptico* usa el primero; *docs* el segundo. VERIFIQUÉ que `keyboard_get_keycode_from_physical(keycode) -> Key` existe. Añadí valor real que ninguna lente citó completo: GH-110751, **devuelve 0 en macOS** — lo marqué como pitfall con fallback. Presento ambas APIs porque las dos son válidas para mostrar la tecla al jugador.

5. **`set_input_as_handled` — dónde vive.** *docs* señaló correctamente que la doc dice "SceneTree" pero el método real está en Viewport; `get_viewport().set_input_as_handled()`. Las otras lentes ya usaban esa forma. Unifiqué a `get_viewport().set_input_as_handled()`.

6. **Deadzone default de acción nueva.** *docs* y *veterano* dicen `add_action` default = **0.5** (no 0.2). Las acciones `ui_*` usan 0.2 vía project.godot. Mantengo el 0.5 como el dato verificado contra `class_inputmap.html` y lo destaco porque es contraintuitivo.

7. **Detección de esquema: umbral de drift.** *docs* y *escéptico* C# usan `0.5` en un sitio y `0.2` en otro; *veterano* usa `0.2` como `STICK_DEADZONE`. Adjudiqué: `0.5` para **capturar un rebind** (quieres una pulsación deliberada del eje), `0.2` para **detección de esquema** (quieres reaccionar antes pero filtrando drift). Ambos umbrales aparecen en el código por esa razón, no por inconsistencia.

8. **Bugs de vibración.** Las tres lentes citan distintos issues (escéptico el set más amplio: #68638, #89136, #94265, #14634, #73446; veterano #94265/#88674/#73446). Consolidé los verificables sin duplicar. No pude abrir GitHub para verificar cada número individualmente (WebFetch a docs dio 403 vía proxy), pero los números son consistentes entre dos lentes independientes y describen comportamiento de plataforma plausible y conocido; los mantengo como referencia, no como API.

**Descartado por dudoso:** nada se descartó como falso. Todo el material convergía. La única cosa que NO afirmo con rotundidad son los números de issue de vibración que solo aparecen en una lente (los dejé pero atribuidos al síntoma, no como garantía).

**Nota de verificación:** no había binario `godot` en el entorno para `--check-only`, y `docs.godotengine.org` devolvió 403 vía el proxy a WebFetch; usé WebSearch (que sí resolvió) para confirmar `action_release` y `keyboard_get_keycode_from_physical`. El código GDScript/C# se revisó manualmente para tipado y firmas idiomáticas 4.6.

## Fuentes

- https://docs.godotengine.org/en/stable/classes/class_input.html
- https://docs.godotengine.org/en/stable/classes/class_inputmap.html
- https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html
- https://docs.godotengine.org/en/stable/classes/class_inputeventjoypadmotion.html
- https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
- https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html
- https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html
- https://github.com/godotengine/godot/issues/73339
- https://github.com/godotengine/godot/issues/63734
- https://github.com/godotengine/godot/issues/100491
- https://github.com/godotengine/godot/issues/110751
- https://github.com/godotengine/godot/issues/76566
- https://github.com/godotengine/godot/issues/90515
- https://github.com/godotengine/godot/issues/85124
- https://github.com/godotengine/godot/issues/94265
- https://github.com/godotengine/godot/issues/88674
- https://github.com/godotengine/godot/issues/73446
- https://github.com/godotengine/godot/issues/112802
- https://github.com/godotengine/godot-proposals/issues/7161
- https://github.com/godotengine/godot-proposals/issues/8519
- https://github.com/KoBeWi/Godot-Input-Remap
- https://github.com/mdqinc/SDL_GameControllerDB
- https://forum.godotengine.org/t/inputeventkey-as-text-key-label-returns-unset/103222
- https://kidscancode.org/godot_recipes/4.x/input/custom_actions/index.html
