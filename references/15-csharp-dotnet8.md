## 15. C# .NET 8 a fondo

Godot 4.6 (publicado 2026-01-27, ~4.6.3) ejecuta C# sobre **.NET 8 (LTS)**. Mono fue descontinuado: el runtime es .NET 8 puro. Hay tres choques que atascan a CASI todo dev/IA que llega de Unity, ASP.NET o GDScript, y conviene tratarlos como el núcleo del tema: (1) **source generators + `partial`**, (2) **marshalling vía Variant**, (3) **ciclo de vida `GodotObject` vs GC de .NET**. Una IA construyendo un RPG se queda atascada SIEMPRE en los mismos sitios; abajo van con su mensaje literal y su desatasque.

### Enfoque nativo recomendado

Antes de elegir lenguaje, una restricción dura que decide la arquitectura: **el web NO soporta C# en 4.6**. La causa es del runtime .NET, no del renderer: el runtime .NET hoy solo puede compilarse como "main module" y carece de código position-independent, así que no se embebe en el export WASM (issue abierto GH-70796). Aparte, el export web usa el renderer Compatibility, pero eso es ortogonal: el bloqueo de C# es del runtime, no del renderer. No hay flag que lo arregle. Si tu RPG 3D apunta a navegador, el core jugable va en GDScript o haces doble export.

Recomendación de reuso (ponytail) por encima de escribir código:
- **No escribas un `.csproj` a mano.** Deja que Godot lo cree: **Project > Tools > C# > Create C# solution**. El `Sdk="Godot.NET.Sdk/4.6.x"` y el `<TargetFramework>net8.0</TargetFramework>` los pone bien y evitas mismatches de versión.
- **No reimplementes señales/observabilidad ni reflexión de exports**: los source generators del `Godot.NET.Sdk` ya generan `SignalName`/`MethodName`/`PropertyName`, el helper `EmitSignalXxx`, y el registro de `[Export]`. Vienen dentro del SDK, no necesitas addon.
- **No reinventes async/corrutinas para gameplay simple**: `ToSignal` + un `CancellationTokenSource` basta. Solo para secuencias serias de combate/cinemáticas considera el addon GDTask.
- **Para datos hereda de `Resource`/`RefCounted`** (autogestión por refcount) y reserva `Node` para el árbol de escena. Menos código de liberación manual = menos `ObjectDisposedException`.

Cuándo C# y cuándo GDScript en un RPG 3D (consenso 2025-2026, ya no es "C# = rápido"):
- **C#** para el core CPU-intensivo: sistema de stats, IA de combate por turnos con muchas iteraciones, RNG determinista, A*/pathfinding a gran escala, serialización de saves grandes, y si el equipo viene de .NET (tooling Rider/VS, tests, generics).
- **GDScript tipado** para nodos de escena, UI, glue, hot-reload, y es el **único camino a web**.
- **Regla anti-atasco transversal:** cada cruce de la frontera C#↔engine paga marshalling Variant. No cruces en bucles calientes: cachea nodos en `_Ready` (no en `_Process`), y copia un `Godot.Collections.Array` a un `T[]`/`List<T>` de System antes de iterar miles de veces.

### GDScript

```gdscript
extends CharacterBody3D
@export var speed: float = 6.0
signal health_changed(old_hp: int, new_hp: int)
var hp := 100

func _physics_process(delta: float) -> void:
    velocity.x = Input.get_axis("left", "right") * speed
    move_and_slide()

func damage(amount: int) -> void:
    var old := hp
    hp -= amount
    health_changed.emit(old, hp)

func _ready() -> void:
    await get_tree().create_timer(1.5).timeout
    if is_instance_valid(self):
        position = Vector3.ZERO
```

### C# (.NET 8)

Ver bloque de ejemplos (`Player.cs`, `Inventory.cs`, `Game.csproj`). Puntos idiomáticos que NO son "GDScript traducido":
- **`delta` es `double`** en los overrides de C# (`_Process(double)`, `_PhysicsProcess(double)`), no `float`. Castea con `(float)delta` cuando lo multipliques por floats.
- API en **PascalCase**: `MoveAndSlide()`, `GetNode<T>()`, `_Ready()`, `Velocity`.
- Emite señales con el **helper tipado generado** `EmitSignalHealthChanged(old, hp)` (wrapper sobre `EmitSignal(SignalName.HealthChanged, ...)`); evita el string mágico `EmitSignal("HealthChanged", ...)`.
- `Velocity = Velocity with { X = ... }` (records/`with` de C# sobre el struct `Vector3`).

### Pitfalls y mensajes de error literales

**Build / toolchain (atasco día 1):**
- `error MSB4236: The SDK 'Godot.NET.Sdk/4.6.x' specified could not be found.` → (a) no hay **.NET 8 SDK** en el PATH de la sesión que lanzó Godot (clásico: PATH OK en SSH pero no en la sesión GUI). `dotnet --list-sdks` debe mostrar un 8.x. (b) Estás usando el binario **estándar** en vez de la build **".NET"/"Mono"** (`Godot_v4.6-stable_mono_*`); el editor estándar no abre proyectos C#. (c) El feed `nuget.org` no resuelve `Godot.NET.Sdk` (el primer restore necesita red). (GH-58955)
- `CS0246: The type or namespace name 'Vector3I' could not be found` → casi siempre `bin/`+`obj/` corruptos tras cambiar de versión de Godot, o nombre mal escrito (en 4.x es `Vector3I`/`Vector2I`, PascalCase). Borra `.godot/mono`, `bin/`, `obj/`, rebuild. (GH-68411)

**Source generators / `partial`:**
- `GD0001: Missing partial modifier on declaration of type '...' that derives from 'GodotObject'` → añade `partial`. Toda clase que derive de `GodotObject` (incl. `Node`, `Resource`, `RefCounted`) lo necesita, **y todas las clases de una jerarquía de herencia y todos los `partial` de archivos múltiples**.
- `GD0002` → la clase contenedora de una clase Godot anidada también debe ser `partial`.
- **Niche (GH-104268):** una clase Godot **anidada dentro de una clase genérica** históricamente rompía los source generators con errores crípticos aunque pusieras `partial` en todo (corregido en PR #104279, milestone 4.5, así que en 4.6.x ya va bien). Si lo ves en una versión vieja, el desatasque es sacar la clase al namespace de nivel superior.
- **`SignalName.X` marcado como `CS0246` por el IDE pero compila** → el generador emite el miembro y el language server (OmniSharp/Rider) está desincronizado. Fix: `dotnet build` desde terminal, reinicia el servidor de lenguaje, borra `obj/`+`bin/`. NO recurras al string mágico para "callarlo". (GH-81674, GH-82268)

**Señales:**
- `GD0201: The name of the delegate must end with 'EventHandler'` → `delegate void DiedEventHandler(...)`.
- `GD0202: The parameter of the delegate signature of the signal is not supported` → un parámetro no es Variant-compatible (`List<int>`, POCO custom, `System.Action`). Cámbialo a tipo Variant o hazlo derivar de `Resource`/`GodotObject`.
- `GD0203` → el delegate de señal debe retornar `void`.
- **(GH-82268)** emitir una señal definida en OTRA instancia desde fuera con el helper tipado no se puede directamente; llama a un método de esa instancia que emita la suya.

**Marshalling / colecciones / genéricos:**
- `GD0102: The type of the exported member is not supported` → no puedes exportar `System.Collections.Generic.List<T>` (GH-70298), ni arrays de `Vector2I/3I/4I` (GH-95358), ni arrays de enums (GH-95813). Usa `Godot.Collections.Array<T>`.
- `GD0301: The generic type argument must be a Variant compatible type` y `GD0302: The generic type parameter 'T' must be annotated with the '[MustBeVariant]' attribute` → en métodos genéricos que tocan Variant: `void Foo<[MustBeVariant] T>(T v)`.
- **Niche (GH-91345):** `CSC : warning AD0001: Analyzer 'Godot.SourceGenerators.MustBeVariantAnalyzer' threw an exception` → suele venir de usar `dynamic` o patrones genéricos que el analizador no maneja. Evita `dynamic` en superficies que tocan Variant; usa tipos concretos o `Variant.From<T>()`/`.As<T>()`.
- **Trampa de copia (GH-42484):** leer un valor-tipo de un `Godot.Collections.Dictionary` puede devolver una **copia**; mutarla no afecta al diccionario. Lee, muta, **reescribe**: `dict[key] = modified`.
- **Verificar, no asumir:** circula un reporte de `[Export] Array` que aparece **vacío en el build exportado** por trimming/stripping agresivo. No está confirmado como bug general de 4.6.3; trátalo como check: valida exports/colecciones en un **build exportado real**, no solo en editor.

**Ciclo de vida (compila perfecto, crashea en runtime — el más insidioso):**
- `System.ObjectDisposedException: Cannot access a disposed object. Object name: 'Godot.Node3D'.` → guardaste una ref C# a un `Node` que se liberó (`QueueFree`/cambio de escena/padre destruido). **`IsInstanceValid` es la única forma correcta de chequear vida; NO compares contra `null`** (la ref managed puede seguir no-null sobre un objeto nativo muerto). Patrón:
  ```csharp
  if (GodotObject.IsInstanceValid(_target) && !_target.IsQueuedForDeletion())
      _target.GlobalPosition = pos;
  ```
- **`Dispose()` ≠ `Free()`:** `Dispose()` suelta solo el handle managed, no destruye el objeto nativo, y sobre un `Node`/`TreeItem` puede causar leaks o dobles liberaciones. Usa `QueueFree()`/`Free()` para nodos; nunca `Dispose()` manual de nodos. (GH-86926, GH-107579; fix RefCounted GH/PR-101006)
- **Niche (GH-89105):** `IsInstanceValid` no rastrea bien la disposición cuando se llama dentro de un `CallDeferred` disparado desde código async/multihilo: puede devolver `true` y aun así lanzar. Marshalla todo el toque de nodos al hilo principal con `CallDeferred`/`Callable.From(...).CallDeferred()` y **revalida dentro** del deferred.

**async/await:**
- `ToSignal(source, signal)` devuelve un `SignalAwaiter` (no un `Task`); se usa con `await` pero no compone directo con `Task.WhenAll`. Espera frame: `await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);`. Espera timer: `await ToSignal(GetTree().CreateTimer(1.5f), SceneTreeTimer.SignalName.Timeout);`.
- **El disposed mid-await:** tras un `await` el nodo pudo morir. Revalida `IsInstanceValid(this)` tras CADA await, o usa un `CancellationTokenSource` cancelado en `_ExitTree()`. `ToSignal` aún no acepta `CancellationToken` nativo (proposals GH-11909 / discussion GH-7993).
- No mezcles `Task.Delay` (hilo del threadpool) con toques a nodos sin volver al hilo principal; `ToSignal` ya resuelve en el hilo del engine.
- **(GH-93608)** una corrutina async puede correr un frame más tras `QueueFree`; no asumas corte inmediato.

**NativeAOT / móvil:**
- Desktop: `<TargetFramework>net8.0</TargetFramework>` + `<PublishAOT>true</PublishAOT>`. Android/iOS: **experimental**; iOS solo exporta desde **macOS + Xcode**, simulador x64; **no cross-OS compile**.
- Trimming rompe rutas de reflexión que Godot usa: corre en editor, crashea al cargar tipos en el build AOT. Añade `TrimmerRootAssembly` para `GodotSharp` y tu assembly.
- **(GH-102747)** el publish AOT falla con **espacios en el nombre del proyecto**. Renombra sin espacios.
- **Web no se salva con AOT: C# sigue sin web en 4.6.**

### Cómo no quedarte atascado (pasos de decisión, en orden de fallo real)

1. **¿Web en el roadmap?** Sí → C# queda casi descartado para el core jugable; usa GDScript. No → sigue.
2. **¿Editor build ".NET/Mono"? ¿`net8.0` en el `.csproj`? ¿`dotnet 8` en el PATH de la sesión GUI?** Si el build no resuelve `Godot.NET.Sdk`, esto es lo primero.
3. **¿Toda clase Godot es `partial`** (y sus contenedoras)? GD0001/GD0002.
4. **¿Lo que cruza al engine** (señales, `[Export]`, genéricos) es **Variant-compatible**? `Godot.Collections.*` en fronteras, `System.Collections.*` solo interno. `[MustBeVariant]` en genéricos. GD0102/GD0202/GD0301/GD0302.
5. **¿`IsInstanceValid` (+ `IsQueuedForDeletion`)** antes de tocar refs cacheadas, tras cada `await`, y **dentro** de deferreds? `QueueFree`, nunca `Dispose()` manual de nodos.
6. **¿`SignalName.X` da CS0246 fantasma?** Rebuild + reset language server, no string-magic.
7. **¿AOT/móvil?** root assemblies, sin espacios en el nombre, target net8, experimental.

### Addon vs construirlo

- **No necesitas addon** para lo canónico: source generators (`[Export]`, `[Signal]`, `SignalName`/`MethodName`/`PropertyName`, helpers `EmitSignalXxx`) y los analizadores GDxxxx **vienen dentro de `Godot.NET.Sdk`**.
- **Opcional, reduce boilerplate de `GetNode`:** `GodotSharp.SourceGenerators` (Cat-Lips) o `godot-tscn-source-generator` (estilo `@onready`). No imprescindibles.
- **Opcional, async serio:** `GDTask` (Fractural, port de UniTask) para `GDTask`, delays sin alocar y cancelación integrada en cinemáticas/secuencias de combate encadenadas. Para 2-3 awaits sueltos, `ToSignal` + `CancellationTokenSource` es suficiente — no metas la dependencia.

**Veredicto ponytail:** el mejor código C# en Godot 4.6 es el que NO escribes: deja que Godot genere el `.csproj`, que los source generators generen señales/exports, que `Resource`/`RefCounted` se autogestionen por refcount, y que `ToSignal` cubra el async simple. El código que SÍ debes escribir es el "core" CPU-intensivo (stats, IA, saves) que justifica salir de GDScript. Y memoriza tres reflejos: `partial` en toda clase Godot, `Godot.Collections.*` en las fronteras del engine, e `IsInstanceValid` antes de tocar cualquier ref que pudo morir. Esos tres reflejos evitan el 90% de los atascos.



> **Escalera ponytail:** meta (decisión de lenguaje) · **net propio:** no es un sistema: es cuándo C# vale la pena sobre GDScript.
