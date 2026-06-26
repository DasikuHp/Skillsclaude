## 5. Inventario / items / equipo

Un inventario en Godot 4.6 no es una "estructura de datos" que tengas que inventar: es la combinación de tres piezas nativas que ya existen y están testeadas — **`Resource`** para definir items como datos (`.tres` data-driven), **`Dictionary[StringName, int]`** tipado para el stacking/los modifiers, y el **drag-and-drop nativo de `Control`** para la UI. No necesitas un addon para empezar, y casi nunca necesitas un "InventoryManager" custom monolítico.

### Enfoque nativo recomendado

**Item = `Resource`, no nodo.** Cada tipo de item es una clase `extends Resource` con `class_name` y campos `@export`. Cada item concreto se guarda como un `.tres` (clic-derecho en FileSystem → *New Resource* → tu clase aparece en el diálogo porque tiene `class_name`). El inventario guarda **una referencia al `Resource` + una cantidad**, nunca un nodo y nunca una copia del blueprint. La doc de [Resource](https://docs.godotengine.org/en/4.6/classes/class_resource.html) y los tutoriales de [StraySpark](https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide) coinciden en este patrón.

**Stacking y modifiers = `Dictionary[StringName, int]`.** La sintaxis de diccionario tipado confirmada en la [doc 4.6 de Dictionary](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html) es `Dictionary[K, V]`. Para mapear `id -> cantidad` o `stat -> bonus`, `Dictionary[StringName, int]` da chequeo de tipos en runtime y claves interned (comparación por puntero, ideal para IDs comparados a menudo). Clave práctica: **el acceso por punto (`dict.key`) no es fiable con claves `StringName`** — es azúcar para claves `String` — usa siempre indexación `dict[&"key"]` ([forum](https://forum.godotengine.org/t/is-dictionary-dot-syntax-my-dictionary-my-key-compatible-with-stringname-keys/104092)).

**UI = drag-and-drop nativo de `Control`.** Los tres métodos virtuales (firmas confirmadas en la [doc de Control](https://docs.godotengine.org/en/4.6/classes/class_control.html)):

```gdscript
func _get_drag_data(at_position: Vector2) -> Variant
func _can_drop_data(at_position: Vector2, data: Variant) -> bool
func _drop_data(at_position: Vector2, data: Variant) -> void
```

- `_get_drag_data` devuelve el dato arrastrable (o `null` si no hay nada). Aquí se llama a `set_drag_preview(control)` para el preview visual que sigue al cursor.
- `_can_drop_data` se invoca **continuamente** sobre el `Control` bajo el cursor: devuelves si ese slot acepta el dato (validar tipo, slot de equipo, espacio).
- `_drop_data` confirma el movimiento: quitar del origen, añadir al destino.

El patrón está documentado en [pdeveloper](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13) y en el inventario Tetris de [MobiusCode](https://mobiuscode.dev/posts/Drag-&-Drop-Tetris-Inventory-System-in-Godot/).

**Equipo = un contenedor separado del inventario.** El patrón recomendado por [Liquid Fire](https://theliquidfire.com/2024/10/23/godot-tactics-rpg-10-items-and-equipment/) y StraySpark: un set de slots `StringName` (HEAD, BODY, PRIMARY, SECONDARY, ACCESSORY), cada slot acepta solo items con el `equip_slot` correspondiente. Al equipar, se aplican los `modifiers` del item a un sistema de stats (un [`Stat extends Resource`](https://medium.com/@minoqi/modular-stat-attribute-system-tutorial-for-godot-4-0bac1c5062ce) con `base_value`, modificadores ordenados y `signal` de actualización para refrescar UI).

**Carga de la "BD" de items:** `ResourceLoader.load(path)`/`preload` para uno suelto, o recorrer un directorio de `.tres` con `DirAccess` y construir un `Dictionary[StringName, ItemData]` indexado por `id` (típicamente en un autoload/singleton).

### GDScript

```gdscript
# item_data.gd — el blueprint inmutable. Un .tres por item.
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var equip_slot: StringName                       # &"" si no es equipable
@export var modifiers: Dictionary[StringName, int] = {}  # stat -> bonus (4.6)
```

```gdscript
# inventory.gd — lógica pura, sin UI. Guarda referencia + cantidad.
class_name Inventory
extends Resource

signal changed

# id -> cantidad. Nota: este ejemplo mínimo apila también los no-apilables por
# simplicidad (un único contador por id). Para estado por instancia (durabilidad,
# encantamientos) guarda copias duplicate(true) en una colección aparte (Array[ItemData]
# o claves únicas por instancia), porque varias instancias colisionarían bajo la misma id.
@export var stacks: Dictionary[StringName, int] = {}
@export var items: Dictionary[StringName, ItemData] = {}  # id -> blueprint

func add_item(item: ItemData, amount: int = 1) -> int:
    items[item.id] = item
    if item.stackable:
        var current: int = stacks.get(item.id, 0)
        var allowed: int = mini(current + amount, item.max_stack)
        var added: int = allowed - current
        stacks[item.id] = allowed
        changed.emit()
        return added
    # No-apilable: en este ejemplo se cuenta igual por id (simplificación intencional).
    stacks[item.id] = stacks.get(item.id, 0) + amount
    changed.emit()
    return amount

func remove_item(id: StringName, amount: int = 1) -> void:
    if not stacks.has(id):
        return
    stacks[id] = maxi(stacks[id] - amount, 0)
    if stacks[id] == 0:
        stacks.erase(id)
        items.erase(id)
    changed.emit()

func count(id: StringName) -> int:
    return stacks.get(id, 0)
```

```gdscript
# inventory_slot.gd — un Control que arrastra y recibe items.
class_name InventorySlot
extends PanelContainer

@export var slot_id: StringName = &""   # &"" => slot de inventario genérico
var item: ItemData

@onready var _icon: TextureRect = $Icon

func set_item(value: ItemData) -> void:
    item = value
    _icon.texture = item.icon if item != null else null

func clear() -> void:
    set_item(null)

func _get_drag_data(_at_position: Vector2) -> Variant:
    if item == null:
        return null
    var preview := TextureRect.new()
    preview.texture = item.icon
    preview.custom_minimum_size = Vector2(48, 48)
    set_drag_preview(preview)
    return {&"source_slot": self, &"item": item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not (data is Dictionary and data.has(&"item")):
        return false
    var dragged: ItemData = data[&"item"]
    # Slot de equipo: solo acepta el equip_slot correcto. Genérico: acepta todo.
    return slot_id == &"" or dragged.equip_slot == slot_id

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    var source: InventorySlot = data[&"source_slot"]
    var dragged: ItemData = data[&"item"]
    source.clear()
    set_item(dragged)   # si slot_id != "", aquí aplicarías dragged.modifiers a stats
```

```gdscript
# Copia única cuando el item tiene estado mutable (durabilidad, encantamientos).
# Los Resource se comparten por referencia: duplicate(true) hace deep copy de las
# propiedades y de los subrecursos referenciados DIRECTAMENTE, PERO NO duplica los
# subrecursos guardados dentro de un Array o un Dictionary (issues #74918 / #82348).
# Si metes Resources mutables dentro de un Dictionary/Array, necesitas un deep_clone()
# manual o duplicar cada subrecurso explícitamente.
var unique := item_template.duplicate(true)
```

### C# (.NET 8)

```csharp
// ItemData.cs — blueprint como Resource. .tres en FileSystem.
using Godot;
using Godot.Collections; // ¡NO System.Collections.Generic para tipos Variant!

[GlobalClass]
public partial class ItemData : Resource
{
    [Export] public StringName Id { get; set; } = "";
    [Export] public string DisplayName { get; set; } = "";
    [Export] public Texture2D Icon { get; set; }
    [Export] public bool Stackable { get; set; } = true;
    [Export] public int MaxStack { get; set; } = 99;
    [Export] public StringName EquipSlot { get; set; } = ""; // "" si no equipable
    [Export] public Dictionary<StringName, int> Modifiers { get; set; } = new();
}
```

```csharp
// InventorySlot.cs — drag-and-drop idiomático en C#.
using Godot;
using Godot.Collections;

public partial class InventorySlot : PanelContainer
{
    [Export] public StringName SlotId { get; set; } = "";
    [Signal] public delegate void ChangedEventHandler();

    private TextureRect _icon;
    public ItemData Item { get; private set; }

    public override void _Ready() => _icon = GetNode<TextureRect>("Icon");

    public void SetItem(ItemData value)
    {
        Item = value;
        _icon.Texture = value?.Icon;
        EmitSignal(SignalName.Changed);
    }

    public void Clear() => SetItem(null);

    // El retorno es Variant (no Variant?): devolver default para "sin datos".
    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (Item == null)
            return default; // historial: issue #78507 sobre retorno null en C#

        var preview = new TextureRect
        {
            Texture = Item.Icon,
            CustomMinimumSize = new Vector2(48, 48),
        };
        SetDragPreview(preview);

        var data = new Dictionary
        {
            { "source_slot", this },
            { "item", Item },
        };
        return data; // Dictionary se convierte implícitamente a Variant
    }

    public override bool _CanDropData(Vector2 atPosition, Variant data)
    {
        // Variant.As<Dictionary>() NO devuelve null si el tipo no coincide:
        // devuelve un Dictionary vacío. Valida el tipo con VariantType para que
        // el guard sea tan robusto como `data is Dictionary` en GDScript.
        if (data.VariantType != Variant.Type.Dictionary)
            return false;
        var dict = data.As<Dictionary>();
        if (!dict.ContainsKey("item"))
            return false;

        var dragged = dict["item"].As<ItemData>();
        return SlotId == "" || dragged.EquipSlot == SlotId;
    }

    public override void _DropData(Vector2 atPosition, Variant data)
    {
        var dict = data.As<Dictionary>();
        var source = dict["source_slot"].As<InventorySlot>();
        var dragged = dict["item"].As<ItemData>();
        source.Clear();
        SetItem(dragged); // aquí aplicarías dragged.Modifiers a tus stats
    }
}
```

Notas C# idiomáticas (.NET 8):
- `[GlobalClass]` hace que `ItemData` aparezca en el diálogo *New Resource*, equivalente a `class_name` en GDScript.
- Usa **`Godot.Collections.Dictionary`/`Array`**, no las de `System.Collections.Generic`, para que crucen el límite engine/Variant. Leer datos arrastrados con `.As<T>()`.
- `_GetDragData` devuelve `Variant` no anulable: para "sin datos" devuelve `default` (no `null`). Esto fue causa del [issue #78507](https://github.com/godotengine/godot/issues/78507).
- **Gotcha 4.6 (C#):** al migrar de 4.5, propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()` → `StringName[]`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Un `string` literal sigue compilando por conversión implícita; **leer** esas propiedades como `string` rompe a nivel de fuente.

### Nodos/clases 4.6

- **`Resource`** + **`@export`** / **`[GlobalClass]`** — items como datos (`.tres`).
- **`Dictionary[StringName, int]`** — stacking y modifiers tipados ([doc 4.6](https://docs.godotengine.org/en/4.6/classes/class_dictionary.html)).
- **`Control`** + `_get_drag_data` / `_can_drop_data` / `_drop_data` / `set_drag_preview` — drag-and-drop nativo ([doc Control](https://docs.godotengine.org/en/4.6/classes/class_control.html)).
- **`GridContainer`** / **`PanelContainer`** / **`TextureRect`** — la rejilla de slots y el icono; sin código de layout custom.
- **`ResourceLoader.load`** / `preload` / **`DirAccess`** — cargar la BD de items.
- **`signal`** / `[Signal] delegate` — `changed` para refrescar UI sin polling.

### Pitfalls

- **Resources compartidos por defecto (la trampa #1).** 50 cofres apuntando al mismo `.tres` comparten estado. Si el item tiene estado mutable, `duplicate(true)` (deep) — pero ojo: `duplicate(true)` copia las propiedades y los subrecursos referenciados **directamente**, y NO los subrecursos guardados dentro de un `Array`/`Dictionary` (issues [#74918](https://github.com/godotengine/godot/issues/74918) / #82348); `duplicate()` simple tampoco copia subrecursos anidados ([issue #37222](https://github.com/godotengine/godot/issues/37222), [forum](https://forum.godotengine.org/t/duplicate-not-making-a-unique-copy-of-my-custom-resource/46404)). Si guardas Resources mutables dentro de colecciones, clónalos a mano. Pero si el item es inmutable (espada genérica), **NO dupliques**: guarda la referencia + cantidad y ya.
- **`resource_local_to_scene`** no siempre instancia una copia local fiable al duplicar instancias de escena ([issue #45350](https://github.com/godotengine/godot/issues/45350)); verifica que cada entidad con stats mutables tenga su propia copia.
- **`dict.key` con claves `StringName`** no es fiable — usa `dict[&"key"]` siempre.
- **No confundir blueprint con instancia.** Mutar el `.tres` muta todos los items de esa plantilla. El inventario referencia el blueprint; el estado va en la instancia/cantidad.
- **C#:** retorno `Variant` (no `null`) en `_GetDragData`; `Godot.Collections.*` no `System.*`; recompilar tras 4.6 por `String`→`StringName` en pistas de animación.

### Addon vs construirlo

| Opción | Estado 4.x | Cuándo usar |
|---|---|---|
| **GLoot** ([peter-kish](https://github.com/peter-kish/gloot)) | El más mantenido; 4.4+, testeado vs 4.7; constraints Grid/Weight/ItemCount; v3.0 en master (rompe con 2.x) | Inventarios grid/peso, prototipado rápido, sistema "universal" ya resuelto |
| **expressobits/inventory-system** ([repo](https://github.com/expressobits/inventory-system)) | Mantenido, modular, nodos, multiplayer | Si necesitas multiplayer y separación lógica/UI desde el día 1 |
| **Whimfoome/godot-InventorySystem** ([repo](https://github.com/Whimfoome/godot-InventorySystem)) | Basado en Resources 4.x | Alternativa ligera centrada en Resources |
| **wyvernbox** ([repo](https://github.com/don-tnowe/godot-wyvernbox-inventory)) | Godot 3 y 4, foco ARPG | Loot tipo Diablo / grid ARPG |
| **Nativo** (Resource + Control DnD) | — | RPG con reglas de equipo/modifiers propias, control total del data model |

Advertencia de migración: **GLoot v3.0 rompe compatibilidad con v2.x** — no actualices a ciegas un proyecto existente.

**Veredicto ponytail:** No construyas un "InventoryManager" singleton monolítico ni un sistema de drag-and-drop a mano ni una estructura de datos custom para stacking. Reutiliza lo nativo: items como `Resource` (`.tres`), `Dictionary[StringName, int]` tipado para stacks/modifiers, y los tres virtuales de `Control` (`_get_drag_data`/`_can_drop_data`/`_drop_data` + `set_drag_preview`) sobre `GridContainer`. Si lo que quieres es grid/peso ya resuelto, instala **GLoot** y no escribas nada. Solo construye el data model propio cuando tus reglas de equipo/stats lo justifiquen — y aun entonces, la UI sigue siendo `Control` nativo.



> **Escalera ponytail:** rung 4–5 (Resource / addon GLoot) · **net propio:** ItemData (Resource) + inventario de datos; UI por señal.
