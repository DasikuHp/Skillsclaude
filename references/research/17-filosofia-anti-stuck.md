## Notas del debate

Las cinco posturas convergen mucho más de lo que su tono adversarial sugiere. Todas firman: composición sobre herencia, datos en `Resource` tipado, reuso de los mecanismos nativos de 4.6 (Jolt, `SkeletonModifier3D`/IK, navegación, señales, `ResourceLoader`). El eje real de disputa es **el timing y la ubicación de la costura tipada propia**.

### Resumen de cada postura

- **P1 — El Purista del Reuso.** "El mejor código es el que no escribes." Datos como `Resource`, comportamiento como nodos componibles, IK/animación/física en árboles nativos, comunicación por señales/grupos. Cede ante: lógica de juego novedosa (combate por turnos), árbol más complejo que el código equivalente, performance medida, claves de save (id en vez de objeto), y target web sin C#.

- **P2 — El Pragmático Pro-Construir.** "Reusa el mecanismo, posee el vocabulario." Aporta la idea más afilada de la síntesis: construir **una abstracción pequeña y tipada en la costura exacta** donde el engine deja de hablar tu idioma de dominio. Criterio concreto: envuelve cuando el engine te da `Variant`/`String` y el literal aparece en ≥3 sitios o cruza subsistemas. Herencia ≤1 nivel sobre el engine. Abstrae a la segunda repetición con test.

- **P3 — Halcón YAGNI.** "La estructura emerge de la repetición observada." Regla de tres: no construyas un sistema global hasta la tercera instancia concreta nombrable. Cuatro disparadores de "esto sobra" (un solo usuario, no nombras la tercera instancia, la indirección no corta acoplamiento real, el manager solo crece). Cede rápido: a la tercera instancia construye, y adelanta la costura de persistencia desde el día 1 porque retrofitearla es explosiva. Reconoce que infra-diseño es tan enemigo como sobre-diseño.

- **P4 — El Abogado de la Escalabilidad.** "Escalar = append, no refactor." Separa DEFINICIÓN (`Resource` en disco) / ESTADO (`RuntimeData`) / PRESENTACIÓN (`Node`). Aporta: `Database` autoload de solo lectura por escaneo de carpeta, referencia por `id: StringName` estable (no path, no objeto), EventBus de hechos de dominio, y la frontera red/save dibujada (no construida) desde el día 1. Test decisivo: "para el contenido N, ¿abro un archivo existente?". Cede ante YAGNI (dibuja, no construye la red) y ante el hot loop (arrays planos, no señales a 60 Hz).

- **P5 — Composición data-driven sobre el árbol.** "El árbol es la verdad; la ambigüedad es el enemigo, no la complejidad." Centra todo en la legibilidad para un agente de IA: una carpeta = un sistema, `class_name` como índice global, señales cableadas en un único punto (`_ready` del actor), `@abstract` como contrato. Heurísticas duras de decisión (tipo→`class_name` vs instancia→autoload; >5 variantes→`Resource` vs ≤5 fijo→enum; notificar→señal vs consultar→llamada directa; 2 niveles de herencia máx).

### Síntesis (cómo se resolvieron las tensiones)

- **Construir vs reusar:** falso dilema. El consenso es "reusa infraestructura, construye reglas de dominio". La tabla de decisión operacionaliza esto caso por caso.
- **¿Cuándo abstraer? (P2/P3 vs P4):** regla de tres como default, con UNA excepción adelantada — la frontera estado serializable / presentación (P4 + P3 coinciden en que es la única costura cara de retrofitear). Todo lo demás nace a la tercera repetición con test.
- **EventBus (P3 escéptico vs P4/P5 pro):** se queda solo para hechos de dominio N×M reales; señales locales directas para todo lo demás. Resuelve la tensión con un criterio medible (≥1 emisor × ≥1 receptor que no comparten árbol).
- **Herencia:** techo de 2 niveles (uno suele ser la clase de engine), unánime.
- **Performance / escala:** todas ceden a data-oriented (arrays planos, MultiMesh) para miles de entidades, pero solo con profiler. El modelo nodo-componente es correcto para un RPG narrativo estándar.
- **Anti-stuck para IA:** P5 aporta el principio rector — elegir siempre la opción legible sin abrir un segundo archivo — combinado con las heurísticas de decisión de P3/P5 y los pasos de recuperación cuando algo falla.

No se hicieron búsquedas web nuevas: todas las afirmaciones técnicas de Godot 4.6 (Jolt default 3D, suite IK bajo `SkeletonModifier3D`/`IKModifier3D`, `Dictionary[K,V]` tipado, `@abstract` desde 4.5, breaking change `String`→`StringName` en `AnimationPlayer` GH-110767, sin C# en web/Compatibility) ya venían ancladas con fuente en las posturas.

## Fuentes

- https://godotengine.org/releases/4.6/
- https://docs.godotengine.org/en/stable/classes/class_ikmodifier3d.html
- https://github.com/godotengine/godot/pull/110767
- https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/
- https://www.gdquest.com/library/save_game_godot4/
- https://godotlearning.com/blog/godot-resources-explained
- https://forum.godotengine.org/t/godot-design-flaw-inheritance-vs-composition/35115
- https://forum.godotengine.org/t/question-about-composition-inheritence/98065
- https://github.com/MysteriousMilk/Godot.Composition
- https://zivadotsh.hashnode.dev/godot-4-autoload-singletons-when-to-use-when-to-avoid
- https://medium.com/@sfmayke/resource-based-architecture-for-godot-4-25bd4b2d9018
- https://school.gdquest.com/glossary/singleton
- https://uhiyama-lab.com/en/notes/godot/custom-resource-data-driven/
- https://dropc-gamestudio.com/concepts/build-powerful-and-scalable-inventories-in-godot/
- https://www.strayspark.studio/blog/godot-4-inventory-crafting-system-complete-guide
