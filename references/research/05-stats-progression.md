## Notas de investigación — Dominio #4: Stats / niveles / progresión (Godot 4.6)

### Verificaciones vía WebSearch (junio 2026)
- **`Curve`**: `bake_resolution` es propiedad int (nº de puntos cacheados); `sample_baked(offset)` usa la caché. Confirmada imprecisión cerca de offset 1.0 (Issue #76623). Eje X normalizado `[0,1]` por defecto — no sirve como tabla por-nivel infinita.
- **Diccionarios tipados**: `@export var x: Dictionary[StringName, float]` válido en 4.x/4.6. Tipos de export limitados a built-in/Resource/Node/enum. Bug conocido al cambiar el tipo de valor de un dict tipado ya serializado (Issue #108488); display correcto en Inspector requiere `class_name` en tipos custom (Issue #109574).
- **C# Resource**: requiere `partial`, hereda `Resource`, `[GlobalClass]`. `[Export]`/`[Signal]` solo Variant-compatibles (diagnóstico GD0202). Señales custom externas dieron error (Issue #82268). Usar `EmitSignal(SignalName.X, ...)`. `+=` no se autodesconecta.
- **Duplicado de Resource**: `duplicate(true)` copia subrecursos pero **no** los que están dentro de Array/Dictionary (Issue #74918). Solo propiedades `@export` se duplican profundamente. `resource_local_to_scene` copia referencia al duplicar instancia (Issue #45350); escenas heredadas problemáticas (Issue #111807). Para runtime, `duplicate(true)` explícito > checkbox.

### Decisiones de diseño
- **Stats = Resource, lógica = Node**: patrón idiomático confirmado en GDQuest Open RPG (BattlerStats) y Minoqi.
- **XP por fórmula, crecimiento de stats por Curve**: separación clave para no usar mal `Curve`.
- **Level-up con `while`**: evita perder niveles con ganancias grandes (foro #70743).
- **Señales propias, no `changed`**: Issue #30179.
- **godot-open-rpg requiere 4.6.2** para abrirse (CHANGELOG).
- **Construir stats, reutilizar UI de skill tree** (Worldmap Builder #2270).

## Fuentes
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/GDQuest/godot-open-rpg/blob/master/CHANGELOG.md
- https://github.com/gdquest-demos/godot-open-rpg/issues/213
- https://minoqi.vercel.app/posts/godot-4-tutorials/stat-system-godot-4-tutorial/
- https://medium.com/@minoqi/modular-stat-attribute-system-tutorial-for-godot-4-0bac1c5062ce
- https://shaggydev.com/2026/04/08/godot-custom-resources/
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-16-level-xp-1ppc
- https://github.com/l-Il/Godot-Action-RPG/blob/main/Stats.gd
- https://docs.godotengine.org/en/4.6/classes/class_dictionary.html
- https://docs.godotengine.org/en/4.6/classes/class_curve.html
- https://forum.godotengine.org/t/sample-curve-beyond-1-infinite-curve-sample/40106
- https://forum.godotengine.org/t/level-up-system-player-gains-multiple-levels/70743
- https://github.com/godotengine/godot/issues/45350
- https://github.com/godotengine/godot/issues/111807
- https://github.com/godotengine/godot/issues/30179
- https://github.com/godotengine/godot/issues/82268
- https://github.com/godotengine/godot/issues/76623
- https://github.com/godotengine/godot/issues/74918
- https://github.com/godotengine/godot/issues/108488
- https://github.com/godotengine/godot/issues/109574
- https://github.com/SeldonHh/Godot_skill_tree_maker
- https://github.com/Reneator/godot-skill-tree
- https://github.com/don-tnowe/godot-worldmap-builder
- https://godotengine.org/asset-library/asset/2270
- https://github.com/Zennyth/EnhancedStat
- https://github.com/samdze/godot-modifiers-plugin
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_global_classes.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_exports.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/c_sharp/c_sharp_differences.rst
