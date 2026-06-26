
Antes de escribir UNA línea de un sistema de RPG en Godot, baja la escalera
ponytail. El motor ya trae casi todo lo de un RPG; la mayoría del "código de
gameplay" es plomería que Godot resuelve con un nodo o un Resource.

## La escalera (aplícala a cada sistema antes de codear)

1. ¿Hace falta que exista? Un RPG no necesita un `GameManager` singleton el día 1.
2. ¿Lo da un **nodo** de Godot? `CharacterBody3D`, `NavigationAgent3D`, `AnimationTree`, `AudioStreamPlayer3D`, `GPUParticles3D`. No reescribas su lógica.
3. ¿Lo da un **Resource**? Items, stats, recetas, diálogos, loot tables = `Resource` con `@export`. No clases de datos a mano, no JSON parseado a mano.
4. ¿Lo dan **señales + grupos + autoloads**? Es el bus de eventos nativo. No escribas tu propio EventBus si una señal basta.
5. ¿Es una línea? `velocity = direction * speed; move_and_slide()` ya es tu locomoción. No envuelvas `move_and_slide` en un framework.
6. Solo entonces: escribe el mínimo que funciona, tipado.

El veredicto ponytail al revisar un sistema: `net: -<N> líneas posibles.` Si no hay nada que cortar y usa nodos nativos: `Limpio. A jugar.`

## Qué trae 4.6 que cambia tus decisiones

- **Jolt es el motor de física 3D por defecto** en proyectos nuevos (2-3× en escenas complejas). No instales plugins de física; no toques el `PhysicsServer` salvo necesidad real. Si migras un proyecto 4.5, actívalo en Project Settings → Physics → 3D → Physics Engine = Jolt.
- **`IKModifier3D`** integra IK en el núcleo: FABRIK (cadenas: colas, tentáculos, columna), CCD (aproximado y rápido para tiempo real), y two-bone IK (óptimo para brazos/piernas, p. ej. pies pegados al terreno). Antes esto era un plugin o math propio: ahora es un nodo hijo del `Skeleton3D`. Bórralo de tu TODO de "escribir IK".
- **SSR rehecho** (reflejos screen-space más estables, mejor roughness, más rápido) y **LOD** que preserva mejor la forma de mallas multi-parte. Calidad gratis: no hagas tu propio sistema de impostores para empezar.
- **Diccionarios tipados**: `Dictionary[String, ItemData]`. Inspector mejor y type-safety. Úsalos para inventarios/tablas en vez de `Dictionary` suelto.
- **Clases y métodos `@abstract`** (desde 4.5): define la base de tus estados/items como abstracta en vez de simular interfaces con `assert`.
- **GDScript más rápido** por optimizaciones de bytecode, sobre todo en **código tipado**. Regla 4.6: si te importa el rendimiento de GDScript, **tipa todo** (`var hp: int`, `func take(dmg: int) -> void`). El tipado no es estilo, es velocidad.
- **Editor**: Select y Transform desacoplados (modo Transform + modo Select-only); GridMap pinta/borra con interpolación Bresenham (líneas sólidas al arrastrar). Útil para construir mazmorras con GridMap.

## GDScript vs C#: elige una, no las mezcles por sistema

- **GDScript** por defecto: iteración instantánea, integración total con el editor, señales y `@export` sin fricción. En 4.6 tipado va sobrado para la lógica de un RPG. Es la opción ponytail (menos andamiaje).
- **C#** solo si ya lo justificas: simulación pesada en CPU (pathfinding masivo, ECS propio, miles de entidades), o reutilizar librerías .NET. Usa **.NET 8**; en desktop todos los runtimes; NativeAOT (`PublishAOT=true`, target ≥ net7) para arranque rápido. Android/iOS con NativeAOT siguen **experimentales** y web **no** soporta C#. Si tu RPG apunta a web, GDScript.
- No partas un mismo sistema entre los dos lenguajes por moda. El cruce GDScript↔C# tiene coste de marshalling; cruza por arquitectura, no por capricho.

# Los 10 sistemas de un RPG en profundidad

Las siguientes 10 secciones cubren cada sistema con el enfoque nativo de 4.6, código **GDScript y C# (.NET 8)** listo para compilar, nodos/clases exactos, pitfalls, decisión *addon vs construirlo* y veredicto ponytail. Se apoyan en investigación web de junio 2026 (docs oficiales 4.6, GitHub, foro de Godot, GDQuest, Asset Library, StackOverflow); cada una cita sus fuentes reales y las notas completas están en [`godot-rpg-research/`](./godot-rpg-research/). Ejemplos ejecutables por sistema en [`godot-rpg-examples/`](./godot-rpg-examples/).



## Lazy, no negligente (límite de la escalera)

La pereza ponytail aplica SOLO al código que no aporta. **NUNCA se recorta** en
los límites de confianza ni en lo que protege al jugador o sus datos:

- **Validación de entrada** en límites de confianza (saves cargados, datos de
  red, input del usuario, archivos externos). Un save corrupto no debe crashear.
- **Manejo de errores**: nunca tragues fallos que pierden progreso del jugador.
- **Seguridad**: no cargues `.tres`/`.gd` arbitrarios de un save (ejecutan código);
  valida ids contra una base conocida.
- **Accesibilidad**: remapeo de input, tamaños de fuente, subtítulos — no son
  "extra", son parte del mínimo viable.

Si un atajo tiene un **techo conocido** (un lock global, un O(n²), una heurística
naive), el comentario nombra el techo y el camino de mejora:

```gdscript
# TECHO: este escaneo es O(n) por frame; ok hasta ~200 items.
# UPGRADE: indexar por id en un Dictionary si el inventario crece.
```

## Formato del veredicto

Cada sistema termina con un veredicto que declara **en qué peldaño se detuvo** la
escalera y cuánto código propio queda:

> **Veredicto ponytail:** <qué NO construir> · <qué reusar>.
> **Escalera:** rung N (nombre) · **net propio:** <líneas/arquitectura que sí escribes>.

`net` es honesto: el grueso del sistema lo da el motor; tú escribes solo el
pegamento. El benchmark público de ponytail reporta reducciones de **-54% a -94%**
de código frente a construir desde cero
([ponytail](https://github.com/DietrichGebert/ponytail)).
