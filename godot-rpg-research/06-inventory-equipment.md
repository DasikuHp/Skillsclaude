## Notas de investigación — Dominio #5: Inventario / items / equipo (Godot 4.6)

### Hechos verificados
- Drag-and-drop nativo de `Control` confirmado vía doc de la clase Control y artículos: tres virtuales `_get_drag_data(Vector2) -> Variant`, `_can_drop_data(Vector2, Variant) -> bool`, `_drop_data(Vector2, Variant) -> void`, con `set_drag_preview(Control)` llamado dentro de `_get_drag_data`. `_can_drop_data` se llama continuamente sobre el Control bajo el cursor.
- `Dictionary[K, V]` tipado confirmado en la doc 4.6 de Dictionary. `Dictionary[StringName, int]` válido. StringName = strings interned, comparación por puntero. Acceso `dict.key` NO fiable con claves StringName -> usar `dict[&"key"]`.
- Items como `Resource` + `@export` (`[GlobalClass]`/`[Export]` en C#); `.tres` data-driven; clase aparece en *New Resource* por tener `class_name`/`[GlobalClass]`.
- C#: `_GetDragData` retorna `Variant` no anulable (no `null`, usar `default`). Issue #78507 documenta el historial del bug del tipo de retorno. Usar `Godot.Collections.Dictionary/Array` (no `System.*`) para cruzar el límite Variant; leer con `.As<T>()`.
- Gotcha 4.5->4.6: nombres de pista de AnimationPlayer pasaron de String a StringName -> recompilar C#.
- Resources compartidos por defecto: `duplicate(true)` para deep copy de subrecursos; `duplicate()` simple no basta (issue #37222). `resource_local_to_scene` no siempre fiable (issue #45350).

### Addons
- GLoot (peter-kish): el más mantenido, 4.4+, testeado vs 4.7, constraints Grid/Weight/ItemCount, v3.0 en master rompe con 2.x.
- expressobits/inventory-system: modular, nodos, multiplayer.
- Whimfoome, wyvernbox: alternativas (ligera / ARPG).

### Incertidumbre
- No se pudo cargar una página de tutorial dedicada de drag-and-drop en docs.godotengine.org; firmas confirmadas vía doc de clase Control + artículos/issues, consistente con la búsqueda actual (junio 2026).

## Fuentes
- https://github.com/peter-kish/gloot
- https://github.com/peter-kish/gloot/blob/master/docs/inventory.md
- https://github.com/expressobits/inventory-system
- https://github.com/gdquest-demos/godot-open-rpg
- https://github.com/alfredbaudisch/GodotDynamicInventorySystem
- https://github.com/Whimfoome/godot-InventorySystem
- https://github.com/SlashScreen/skelerealms
- https://github.com/don-tnowe/godot-wyvernbox-inventory
- https://docs.godotengine.org/en/4.6/classes/class_dictionary.html
- https://docs.godotengine.org/en/4.6/classes/class_resource.html
- https://docs.godotengine.org/en/stable/classes/class_control.html
- https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13
- https://godot.snoeyz.com/drag-and-drop/
- https://mobiuscode.dev/posts/Drag-&-Drop-Tetris-Inventory-System-in-Godot/
- https://github.com/godotengine/godot/issues/78507
- https://github.com/godotengine/godot/issues/37222
- https://github.com/godotengine/godot/issues/45350
- https://forum.godotengine.org/t/duplicate-not-making-a-unique-copy-of-my-custom-resource/46404
- https://forum.godotengine.org/t/is-dictionary-dot-syntax-my-dictionary-my-key-compatible-with-stringname-keys/104092
- https://theliquidfire.com/2024/10/23/godot-tactics-rpg-10-items-and-equipment/
- https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide
- https://medium.com/@minoqi/modular-stat-attribute-system-tutorial-for-godot-4-0bac1c5062ce
- https://codingquests.io/blog/godot-4-inventory-system-tutorial
- https://godotengine.org/asset-library/asset/1368
