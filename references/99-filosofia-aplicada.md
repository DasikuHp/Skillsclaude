## Filosofía aplicada: construir vs reusar y cómo no quedarte atascado

Las cinco posturas, por debajo de su retórica, dicen lo mismo con distinto acento: **en Godot 4.6 ya tienes una arquitectura de fábrica** (árbol de escenas, señales, `Resource` tipados, autoloads, Jolt, `SkeletonModifier3D`/IK, `NavigationAgent3D`). Tu trabajo no es reconstruir eso, sino *cablearlo* y escribir solo las **reglas de tu juego**. El desacuerdo real no es "reusar o construir" — todas dicen "reusar el mecanismo del engine" — sino **dónde y cuándo pones tu propia costura tipada**, y eso es lo que esta síntesis calibra.

### Principios (lo que las 5 firman)

1. **Reusa el mecanismo, posee el vocabulario.** Física, animación, IK, navegación, serialización: del engine, intactos. HP, daño, quests, loot, iniciativa de combate: tuyos, escritos de verdad. Confundir ambos produce los dos fracasos gemelos — *infra-diseño* (pegar nodos sin lógica de dominio donde hace falta) y *sobre-diseño* (frameworks caseros que reimplementan el engine peor).
2. **Datos en `Resource` tipado; comportamiento en nodos-componente; nunca los mezcles.** Un `ItemDef extends Resource` es el *qué*; un `WeaponComponent extends Node` es el *cómo*. Usa `Array[T]` y `Dictionary[K,V]` tipados (estables en 4.6) en los `@export`.
3. **Composición sobre herencia.** Techo duro: **2 niveles de herencia** (uno de ellos suele ser la clase de engine, p.ej. `Actor extends CharacterBody3D`). Más allá, compón con nodos-componente. `@abstract` (4.5+) es para *contratos* (`State`, `Ability`), no para torres de abstracción.
4. **Señales locales primero; bus global solo para hechos de dominio N×M.** Cablea directo mientras el árbol te dé acceso. Un `EventBus` autoload transporta *hechos* (`entity_died`), no comandos de UI ni eventos entre dos hermanos.
5. **Referencia por `id: StringName` estable, no por path ni por objeto.** Los saves y la red sobreviven a mover archivos solo si la clave es estable. (El propio 4.6 movió props de animación de `String`→`StringName`: sigue esa lógica para *tus* claves.)
6. **El árbol es la documentación.** Un `.tscn` componible se lee de un vistazo; una jerarquía profunda obliga a abrir 4 archivos. Esto importa especialmente para un agente de IA que debe reconstruir el modelo mental sin adivinar.

### Tabla de decisión: reusar vs construir

| Necesidad | Acción | Por qué |
|---|---|---|
| Física, character controller | **Reusa** `CharacterBody3D.move_and_slide()` sobre Jolt (default 3D en 4.6) | El engine lo testea en C++ cada release |
| IK (pies en terreno, mano agarra arma) | **Reusa** el solver más simple: `TwoBoneIK3D` (2 huesos), `FABRIK3D`/`CCDIK3D` (cadenas; la suite completa incluye también `ChainIK3D`, `SplineIK3D`, `IterateIK3D`) | Nunca escribas tu propio solver; `JacobianIK3D` solo si lo mides necesario |
| Máquina de estados de locomoción (idle/run/jump) | **Reusa** `AnimationTree` + `AnimationNodeStateMachine` (grafo, controlado por `AnimationNodeStateMachinePlayback.travel()`) | Evita el `match state:` de 200 líneas; además los nombres de animación pasaron de `String` a `StringName` en 4.6, otra razón para no manejar transiciones a mano con strings |
| Navegación / pathfinding | **Reusa** `NavigationAgent3D` + `NavigationRegion3D` | No escribas A\* propio |
| Serialización / save | **Reusa** `ResourceLoader`/`ResourceSaver` con datos como `Resource` | Versionan, cachean y referencian gratis |
| Definición de item/quest/skill | **Construye** un `Resource` tipado (`.tres`) por entrada | Editable en Inspector, testeable, escala por *append* |
| Estado mutable de runtime (HP actual, stack count) | **Construye** un tipo *aparte* (`ItemStack`, no `ItemDef`); jamás muta la definición | El `Resource` definición es plantilla inmutable compartida |
| Reglas de combate, turnos, iniciativa | **Construye** GDScript propio, y hazlo bien | Es tu propiedad intelectual; el engine no la tiene |
| Comunicación padre↔hijo / hermanos | **Reusa** señal local directa, cableada en `_ready` del actor | Tipada, refactorizable por el editor, un solo punto de cableado |
| Comunicación entre sistemas lejanos (kill→quest+UI+logros) | **Construye** `EventBus` autoload de señales — *solo si* hay N×M real | Si hay 1 emisor + 1 receptor, conecta directo: el bus solo añade un salto y borra el tipo |
| Índice de contenido (cientos de items) | **Construye** un autoload `Database` de **solo lectura** que escanea carpeta | Añadir item = soltar un `.tres`, cero código tocado; nunca un `match id:` |
| Envolver un literal de string mágico | **Construye** una constante (`const ATTACK := &"attack"`) **solo** si aparece en ≥3 sitios o cruza subsistemas | Una sola aparición local no justifica una clase |

### Checklist anti sobre-diseño (señales de que SOBRA)

- La clase/nodo/autoload tiene **exactamente un usuario** → es un método que se fue de casa. Vuelve.
- No puedes **nombrar la tercera instancia concreta** que usará la abstracción → es ficción.
- La indirección **no elimina ningún acoplamiento real**, solo lo mueve (EventBus con 1 emisor y 1 receptor).
- El autoload **solo crece y nunca encoge** → va camino del God-`GameManager` de 1.200 líneas.
- Estás construyendo un "sistema genérico extensible de X" **antes de tener un solo X funcionando**.
- Pusiste una capa (`PhysicsWrapper`, `InputAbstraction`) "por si cambiamos de motor" → no vas a cambiar de motor.
- Tienes `ItemDef` + `ItemStack` + `ItemView` para una mecánica que **podrías descartar mañana** → prototipa inline, promueve a arquitectura cuando sobreviva.

### Checklist anti infra-diseño (señales de que FALTA)

- Combate, inventario y diálogo viven en el `_process` del `Player` → ya pasaste la regla de tres, es una bola de barro.
- Stats/items como **campos de un singleton** o `Dictionary` crudos (`{"hp":100}`) → no editables en Inspector, no testeables, claves mágicas que fallan en runtime, no en compilación.
- El **estado de verdad vive en el árbol de nodos** (HP leído del nodo de malla) → save/load y multijugador imposibles sin reescribir.
- Referencias por **path frágil** (`$"../../Player/Health"`) regadas por el código.
- **Pegas nodos sin escribir las reglas del dominio** donde el engine no las tiene (combate por turnos con reacciones no es un nodo).

### La costura preventiva que SÍ se adelanta

Hay un único boundary que conviene *dibujar* desde el día 1 aunque no lo necesites aún, porque retrofitearlo es explosivo (toca N sistemas), no lineal: **estado serializable vs presentación**. Los datos nacen como `Resource` con `id` estable a un lado; modelos, `AnimationTree`, partículas, IK (`LookAtModifier3D`) al otro, y la presentación se reconstruye desde el estado, nunca al revés. El resto (EventBus, clase base de `Ability`, `StateMachine` reutilizable) **no se adelanta**: nace a la tercera repetición concreta y nace con su test.

El test que zanja cualquier duda de escala: *"para añadir el contenido número N, ¿tengo que abrir un archivo existente?"* Si no → escalaste bien. Si sí → o sobre-diseñaste una abstracción inútil, o infra-diseñaste y ahora repintas.

### Guía anti-stuck para un agente de IA

Heurísticas de decisión rápida (cuando dudes, elige la opción donde el siguiente lector entiende el flujo *sin abrir un segundo archivo*):

- **¿Tipo de cosa o instancia única global?** Tipo → `class_name` + `Resource`. Instancia única → autoload. (Máx ~3 autoloads al arranque: `Save`, `SceneRouter`, quizá `EventBus`/`AudioDirector`. Nunca un `GameManager`.)
- **¿>5 variantes o contenido autoral, o ≤5 y fijo?** >5/autoral → `Resource` + Database. ≤5 fijo → `enum` + código directo. No montes un pipeline de datos para 3 casos.
- **¿Notificar o consultar?** Notificar (fire-and-forget) → señal. Necesitas un valor de vuelta ya (`can_afford(cost) -> bool`) → llamada directa tipada.
- **¿La cadena `extends` propia pasa de 1 nivel sobre el engine?** → conviértelo en composición.
- **¿El literal/abstracción aparece <3 veces?** → no lo envuelvas todavía.

Qué hacer cuando algo no funciona (romper el bucle):

1. **Antes de escribir, busca el nodo nativo.** El 90% de "necesito programar X" en infraestructura ya es un nodo. Si reescribiste un solver de IK o un loop de física, deshazlo.
2. **Si un campo aparece "de la nada" (`velocity`, `hp`), el árbol y los tipos son la verdad** — no infieras, observa el `.tscn` y el `class_name`. Si para entenderlo tienes que leer 4 archivos, la jerarquía está mal: aplana a composición.
3. **Si un error de coerción aparece en runtime y no en compilación**, sospecha de string mágico (`play("attack")`) o `Dictionary` no tipado como payload. Tipa la costura.
4. **Si te atascas configurando**, no toques defaults (`ssr_depth_tolerance`, etc.) hasta ver el artefacto real. Configurar prematuramente es escribir código por otros medios.
5. **Si dudas entre dos diseños, elige el más pequeño y duplica el código.** Extrae a la segunda repetición dolorosa, no antes. La extracción especulativa es exactamente lo que infla el proyecto hasta atascarte en tu propio andamiaje.
6. **Plataforma manda y se decide temprano:** si el target es web → renderer `Compatibility` y **sin C#**: todo el core en GDScript. No diseñes en .NET lo que correrá en navegador.
7. **Performance: cede solo con profiler en mano.** Nodo-componente + señales es correcto para protagonista + decenas de NPCs. Para miles de entidades (hordas, auto-battler) cede a arrays planos / `MultiMeshInstance3D` / servidores directos — pero solo tras medir, nunca a priori.

**Síntesis operativa:** *Datos en `Resource` tipado, comportamiento en nodos-componente componibles, infraestructura en sistemas nativos (Jolt, `AnimationTree`, IK, navegación), comunicación por señales locales y un EventBus solo para hechos N×M. Referencia por `id` estable. Dibuja la frontera estado/presentación el día 1; todo lo demás nace a la tercera repetición, con test. Escribe GDScript propio solo para las reglas del juego — y ahí, escríbelo de verdad.*

## Estructura mínima de proyecto libre

```
/scenes      escenas .tscn (player, enemigos, niveles, UI)
/scripts     .gd o .cs por sistema
/resources   .tres: items, stats, diálogos, loot
/autoload    singletons SOLO si son globales de verdad (settings, save)
LICENSE      MIT/GPL para que sea libre de verdad
```

Autoloads (singletons) con moderación: settings y save sí; un `Global` que lo toca todo, no. Cada autoload extra es estado global que ponytail marcará para borrar.

## Límites de este skill

Alcance: arquitectura y decisiones de "qué nodo/recurso usa Godot 4.6 por mí" para un RPG 3D libre. **No** sustituye la documentación oficial de la API ni decide tu game design. Para firmas exactas de métodos, consulta los docs de 4.6. Para nombres de assets, balance o narrativa: eso es tu juego, no este skill. Si una feature que cito cambió en un parche 4.6.x, gana la documentación.

## Fuentes

- [Godot 4.6 — Release oficial](https://godotengine.org/releases/4.6/)
- [Godot 4.6 Complete Guide 2026](https://www.live-laugh-love.world/blog/godot-46-complete-guide-2026/)
- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Diccionarios tipados — Godot 4.4 dev snapshot](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-2/)
- [Clases abstractas en GDScript — propuesta #5641](https://github.com/godotengine/godot-proposals/issues/5641)
- [GDScript vs C# en 2026 — StraySpark](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language)
- [C#/.NET en Godot — docs oficiales](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html)
- [Máquina de estados en Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Sistema de inventario y crafteo — StraySpark](https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide)
- [Estado de C# en plataformas — Godot Engine](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/)
- [Concepto ponytail — DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
