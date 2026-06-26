## 11. Shaders para RPG

Los seis efectos clásicos de un RPG 3D (hit-flash, dissolve de muerte, outline/silueta, toon/cel, escudo Fresnel, agua) son cada uno entre 10 y 40 líneas de **Godot Shading Language** en texto (`.gdshader`). El error que atasca a una IA NO es escribir el efecto: es elegir mal el contenedor del material, compartir el recurso entre instancias, usar sintaxis de Godot 3, o no saber qué cambió en 4.6. Esta sección mapea cada efecto a la API exacta y blinda los puntos donde el render se rompe en silencio.

### Enfoque nativo recomendado

**Antes de escribir un shader, elige el contenedor.** El 80% de los bugs "no se ve / se ve raro / se aplica a todo" vienen de aquí:

| Necesitas... | Usa | Por qué |
|---|---|---|
| Reemplazar el look completo (toon, agua) | `ShaderMaterial` en el slot Material | Control total, sin PBR |
| Mantener PBR y AÑADIR un efecto encima (escudo, dissolve overlay) | `StandardMaterial3D` + `Material.next_pass` = `ShaderMaterial` | No reescribes el PBR |
| Outline/silueta de selección o hover | `StandardMaterial3D` → sección **Stencil** (modo Outline, nativo 4.5+) | Cero shader propio |
| Hit-flash en muchos enemigos que comparten material (Forward+/Mobile) | `instance uniform` + `set_instance_shader_parameter()` | No duplica recurso, va por MeshInstance3D — **NO en Compatibility/web** |
| Hit-flash en export **web/Compatibility** | `ShaderMaterial.duplicate()` por enemigo (`resource_local_to_scene = true`) + `set_shader_parameter()` | Compatibility no soporta `instance uniform` ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)) |

Hechos canónicos que evitan la mitad de los atascos:
- `ShaderMaterial` y `StandardMaterial3D` son hermanos (ambos heredan de `Material`/`BaseMaterial3D`). `Material.next_pass` encadena pasadas; **no todo tiene que ser ShaderMaterial**.
- `set_shader_parameter(param: StringName, value: Variant)` vive en `ShaderMaterial`, NO en `Shader`. En 4.x ya **no existe** `set_shader_param` (era Godot 3). Cada `uniform` del shader es un parámetro; el nombre debe coincidir literal.
- **Dos rutas distintas para el mismo uniform** y la IA las confunde: por código directo `set_shader_parameter("flash", v)` (sin barra); por Tween/AnimationPlayer la *property path* es `"shader_parameter/flash"` (con barra). Mezclarlas no da error fuerte: simplemente no pasa nada.
- `SCREEN_TEXTURE`, `DEPTH_TEXTURE` y `NORMAL_ROUGHNESS_TEXTURE` **fueron ELIMINADOS como built-ins** ([PR #70967](https://github.com/godotengine/godot/pull/70967)). Ahora son uniforms con hint: `uniform sampler2D screen_tex : hint_screen_texture;`. `SCREEN_UV`, `TIME`, `FRAGCOORD`, `VIEW`, `NORMAL`, `UV` siguen siendo built-ins.

**BREAKING 4.6 que rompe shaders existentes en silencio — y que la IA va a malinterpretar.** En 4.6, dentro de la struct `SceneData` de los **GLSL/compute crudos** (`.glsl`, `CompositorEffect`, `RenderingDevice`), `view_matrix` e `inv_view_matrix` cambiaron de `mat4` a `mat3x4` — y la guía de migración lo **omitió** inicialmente ([godot-docs#11744](https://github.com/godotengine/godot-docs/issues/11744)). Las tres lentes coinciden y verifiqué: esto **NO afecta** a `shader_type spatial` de alto nivel — ahí `VIEW_MATRIX`/`INV_VIEW_MATRIX` siguen siendo `mat4`. Los seis efectos RPG de esta sección son 100% `.gdshader` spatial/canvas_item, así que **no te afecta** salvo que escribas compute shaders. Si tocas `SceneData` en GLSL, el síntoma es geometría deformada o sombras desaparecidas tras actualizar de 4.5; reconstruye con `mat4(...)` o transpón según el orden de la multiplicación. Apunta a ≥4.6.3 (hubo regresiones de SDFGI/sky en snapshots intermedios, [godot#115599](https://github.com/godotengine/godot/issues/115599)).

### GDScript (hit-flash multi-enemigo, el patrón base de un RPG)

El efecto #1 de daño y el bug #1 de RPG: si 30 goblins comparten el `.tres` del `ShaderMaterial`, `set_shader_parameter("flash", 1.0)` los hace **parpadear a todos**. En **Forward+/Mobile** la solución correcta y barata es `instance uniform` + `set_instance_shader_parameter` (apunta al MeshInstance3D, no al recurso). **OJO — esto NO compila en Compatibility (= export web):** los `instance uniform` no están soportados ahí ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)), un shader con `instance uniform float flash` falla a compilar y el material no se renderiza. Para web, duplica el `ShaderMaterial` por enemigo (`material.duplicate()` con `resource_local_to_scene = true`) y usa `set_shader_parameter` normal. Ver bloque de ejemplos al final (incluye la rama web).

### Shader (.gdshader): los seis efectos

Todos verificados como Godot Shading Language 4.x/4.6. Resumen de los built-ins de salida que usan: `ALBEDO`, `EMISSION`, `ALPHA` (fragment); `DIFFUSE_LIGHT`, `SPECULAR_LIGHT` (light, con `+=`). Ver los archivos compilables en la sección de ejemplos.

Notas por efecto:
- **Hit-flash:** `ALBEDO = mix(base, flash_color, flash)`; añade `EMISSION` para que "pegue" con glow (en 4.6 el glow es más brillante). `source_color` en el uniform es **obligatorio** o el color se ve apagado.
- **Dissolve:** ruido + `if (n < dissolve) discard;` + borde `smoothstep`. Usa `render_mode cull_disabled` para no ver el interior hueco. En personajes skinned, samplea el ruido por posición de mundo (triplanar), no por UV, o las costuras se ven feas.
- **Outline:** primero intenta la sección **Stencil → Outline** nativa de `StandardMaterial3D` (cero código). Solo si necesitas X-ray "ver aliados a través de paredes" usa el patrón de dos pases con stencil (abajo). Para mobile barato, casco invertido (`cull_front` + inflar VERTEX por NORMAL).
- **Toon/cel:** sobrescribe `light()` y usa `DIFFUSE_LIGHT += ...` (con `+=`, nunca `=`). El atajo más barato si no necesitas control fino es `render_mode diffuse_toon, specular_toon;`.
- **Escudo Fresnel:** `pow(1.0 - dot(NORMAL, VIEW), power)`. El built-in es `VIEW` (no `VIEW_DIR`). `render_mode blend_add, unshaded, depth_draw_never`.
- **Agua:** desplazamiento en `vertex()`, foam con `hint_depth_texture`. El depth NO es lineal; hay que reconstruir (ver pitfalls). Evítala en el export web (Compatibility).

### Shader (.gdshader): outline por stencil (4.5+, solo si el modo nativo no basta)

Verificado: `stencil_mode write, compare_always, 1;` en el material base y `stencil_mode read, compare_not_equal, 1;` en el `next_pass`. El pase 2 va en el **Next Pass** del material base, o no se ve nada. Ver ejemplo `outline_stencil_pass2.gdshader`.

### Pitfalls y mensajes de error literales

| Mensaje / síntoma | Causa | Fix |
|---|---|---|
| `Unknown identifier in expression: 'SCREEN_TEXTURE'` (o `DEPTH_TEXTURE`) | sintaxis Godot 3 | declara `uniform sampler2D t : hint_screen_texture;` |
| `Unknown identifier in expression: 'VIEW_DIR'` | built-in inventado | es `VIEW` |
| `Invalid call. Nonexistent function 'set_shader_param'` (GDScript) | API Godot 3 | usa `set_shader_parameter()` |
| `Varying must be assigned before using!` | usas un varying en `fragment()`/`light()` sin asignarlo en `vertex()` | declara el varying global, asígnalo SOLO en `vertex()`, léelo en `fragment()` ([#50464](https://github.com/godotengine/godot/issues/50464)) |
| `Expected constant expression after '='` | `const float x = 1.0/1024.0;` o `const ... = pow(x,y);` el parser no evalúa esa aritmética | precalcula el literal o usa un `uniform` ([#33840](https://github.com/godotengine/godot/issues/33840), [#81391](https://github.com/godotengine/godot/issues/81391)) |
| Crash editor `Index is out of bounds` | un `sampler2D` con hint seguido de otro sin hint | pon hints explícitos en todos los samplers contiguos ([#67493](https://github.com/godotengine/godot/issues/67493)) |
| Toda la horda parpadea al herir a uno | `ShaderMaterial` compartido + `set_shader_parameter` | `instance uniform` + `set_instance_shader_parameter` (o `duplicate()` / `local_to_scene`) |
| Flash no se ve / shader no compila en export web | `instance uniform` no soportado en Compatibility ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)) | usa material duplicado por enemigo (`resource_local_to_scene`) + `set_shader_parameter` |
| Instance uniform "contamina" el outline | bug `next_pass`: modificar un instance uniform afecta al del next_pass | no reuses el mismo nombre entre pases ([#83472](https://github.com/godotengine/godot/issues/83472)) |
| `next_pass` ShaderMaterial sobre StandardMaterial3D solo muestra albedo | bug histórico ([#76537](https://github.com/godotengine/godot/issues/76537)) | invierte el orden (base = ShaderMaterial) o verifica `render_mode`/blend del next_pass |
| Foam de agua cambia con la cámara | `texture(depth_tex,uv).r` es depth NDC no-lineal, no metros | reconstruye con `INV_PROJECTION_MATRIX` (ver código) |
| Agua/escudo OK en Forward+, roto en web | Compatibility usa NDC OpenGL; `ndc.z` puede necesitar `raw*2.0-1.0` | rama por renderer o evita screen/depth en web |
| Pantalla negra al cambiar resolución | coexisten `hint_depth_texture` + `hint_screen_texture` | no los mezcles en escenas con resize ([#97728](https://github.com/godotengine/godot/issues/97728)) |
| Líneas rosa gridded con screen texture en web | bug Compatibility ([#79914](https://github.com/godotengine/godot/issues/79914)) | evita screen-space en el build web |
| Outline desaparece en export web | stencil no soportado en Compatibility | fallback a casco invertido o post-proceso |
| Sombra inconsistente con la malla disuelta | `discard` ocurre en el pase regular (tratado a menudo como transparente), así que su comportamiento de sombra no es fiable | para sombras opacas correctas usa `ALPHA` + `ALPHA_SCISSOR_THRESHOLD` (mantiene la malla en el pipeline opaco); [#58924](https://github.com/godotengine/godot/issues/58924) documenta el historial de sombras de alpha-scissor (era el scissor el que fallaba, ya corregido) |

### Cómo no quedarte atascado (pasos de decisión)

1. **¿2D/HUD o mundo 3D?** → `shader_type canvas_item` vs `spatial`. RPG: el mundo es `spatial`, el post-proceso/HUD va en un `canvas_item` sobre un `CanvasLayer`.
2. **¿Reemplazo el material o lo añado encima?** Añadir = `Material.next_pass`. No conviertas un PBR funcional en ShaderMaterial solo para un overlay.
3. **¿Outline?** Primero prueba `StandardMaterial3D` → Stencil → Outline (nativo). Solo escribe shader si necesitas X-ray.
4. **¿El efecto se dispara por instancia (flash, dissolve por enemigo)?** → `instance uniform` + `set_instance_shader_parameter`, NUNCA `set_shader_parameter` sobre recurso compartido.
5. **¿Uso pantalla/profundidad (agua, escudo con intersección, distorsión)?** Asume que se rompe en web (Compatibility). Declara los uniforms con `hint_screen_texture`/`hint_depth_texture`, reconstruye depth lineal, y ten un fallback sin screen-space para el export web.
6. **¿Web?** Renderer = Compatibility, y **web no tiene C#** → escribe la lógica de disparo en GDScript. Sin stencil, sin agua refractiva fiable, y **sin `instance uniform`** ([godot-proposals#6909](https://github.com/godotengine/godot-proposals/issues/6909)): el hit-flash por instancia (el efecto estrella de esta sección) NO compila en web — usa `ShaderMaterial.duplicate()` por enemigo (`resource_local_to_scene = true`) + `set_shader_parameter`.
7. **¿Toca compute/GLSL crudo con `SceneData`?** Solo entonces te afecta `mat3x4`. Para `.gdshader` ignóralo.

### Addon vs construirlo

**Construir** los seis efectos: cada uno es <40 líneas, dependen de tus uniforms/pipeline, y un addon añade acoplamiento sin ahorro. Copia de [godotshaders.com](https://godotshaders.com) y adapta a 4.6 (verifica que no use `SCREEN_TEXTURE` viejo). **Excepción razonable:** una librería de funciones noise/fresnel vía `#include`, y para **agua realista/SSR** sí considerar un asset 4.6 verificado por la complejidad de depth+refracción. **Reusar antes que escribir:** outline (sección Stencil nativa), toon básico (`diffuse_toon`/`specular_toon`), y ruido (`NoiseTexture2D`/`FastNoiseLite` seamless en vez de generar ruido en el shader).

Texto (`.gdshader`) sobre VisualShader para todo: versionable en git, diffeable en PRs, y VisualShader no expone `stencil_mode` ni `light()` custom de forma completa.

**Veredicto ponytail:** el mejor shader es el que no escribes — outline con la sección Stencil nativa de `StandardMaterial3D`, toon con `render_mode diffuse_toon`, ruido con `NoiseTexture2D`. Cuando sí escribas, son 30 líneas: declara tus uniforms con `source_color`/`hint_*`, dispáralos por instancia con `set_instance_shader_parameter` (no revientes la horda entera — pero en web/Compatibility no hay `instance uniform`: ahí duplica el material por enemigo), y recuerda que `SCREEN_TEXTURE` murió en Godot 3. El `mat3x4` de 4.6 es un susto de compute, no de tus efectos.



> **Escalera ponytail:** rung 4 (Stencil/render_mode nativos) · **net propio:** outline/toon nativos primero; un .gdshader es ~30 líneas si lo escribes.
