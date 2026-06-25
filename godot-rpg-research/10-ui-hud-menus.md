## Notas de investigación — Domain #9 UI/HUD/menús (Godot 4.6)

Verifiqué vía WebSearch los puntos centrales del dossier y todos se confirman contra la documentación oficial 4.6/stable:

- **TextureProgressBar/ProgressBar derivan de `Range`**: confirmado. `texture_under`, `texture_progress`, `texture_over`; `fill_mode` con `FILL_LEFT_TO_RIGHT`, `FILL_RIGHT_TO_LEFT`, `FILL_TOP_TO_BOTTOM`, `FILL_BOTTOM_TO_TOP`, `FILL_CLOCKWISE`, `FILL_COUNTER_CLOCKWISE`. `texture_progress` es un `Texture2D` que se recorta según `value`/`fill_mode`.
- **Theming**: `add_theme_stylebox_override(name, stylebox)` y `theme_type_variation` confirmados; existe página 4.6 dedicada de Theme type variations.
- **Pausa**: `get_tree().paused = true` pausa todo; menú debe ser `Always` o `WhenPaused`. Patrón confirmado: CanvasLayer raíz en `Always` y el control del menú en `WhenPaused`. `Node.PROCESS_MODE_*` enum confirmado.
- **Escalado**: `canvas_items` (antes "2d") escala UI manteniendo nitidez; hay bugs históricos de scaling/blurriness en 4.x (GH #88171, #86563) y regresión Android (GH #118153 según dossier).
- **Tween + pausa**: GH #81994 confirma que los tweens independientes se detienen en pausa pese a `Always`.

API C#: el delegado `[Signal] ...EventHandler` genera evento `+=`; `TweenProperty` toma la propiedad como string-path ("value"). Nombre correcto en 4.6 es `AddThemeStyleboxOverride` (con prefijo Theme), no `AddStyleboxOverride`. Gotcha String→StringName de AnimationPlayer 4.5→4.6 obliga a recompilar C#.

WebFetch estaba bloqueado en el entorno de origen del dossier; mis WebSearch confirman las firmas citadas sin contradicción.

## Fuentes
- https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html
- https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html
- https://docs.godotengine.org/en/stable/classes/class_progressbar.html
- https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html
- https://docs.godotengine.org/en/stable/classes/class_control.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_theme_type_variations.html
- https://docs.godotengine.org/en/4.6/tutorials/ui/gui_theme_type_variations.html
- https://docs.godotengine.org/en/stable/classes/class_theme.html
- https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/peter-kish/gloot
- https://github.com/alfredbaudisch/GodotDynamicInventorySystem
- https://github.com/expressobits/inventory-system
- https://github.com/godotengine/awesome-godot
- https://kidscancode.org/godot_recipes/4.x/3d/healthbars/index.html
- https://github.com/godotengine/godot/issues/81994
- https://github.com/godotengine/godot/issues/118153
- https://github.com/godotengine/godot/issues/77729
- https://github.com/JarLowrey/TextureProgressOfSubunits
