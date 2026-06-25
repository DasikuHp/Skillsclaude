## Adjudicación del debate

Las tres lentes fueron inusualmente convergentes; el grueso del trabajo fue eliminar redundancia y resolver micro-contradicciones, no arbitrar desacuerdos de fondo.

**Punto de máxima coincidencia (las 3 lo marcan como el atasco central):** el breaking `mat4→mat3x4` de `SceneData.view_matrix`/`inv_view_matrix` aplica SOLO a GLSL/compute crudo, NO a los built-ins `VIEW_MATRIX`/`INV_VIEW_MATRIX` de `.gdshader` spatial. Verifiqué que esto es correcto. Adjudicación: lo mantengo como advertencia destacada pero **desescalado** — el veterano lo proponía como apertura de la sección ("abre con el breaking de mat3x4"), pero como NINGUNO de los seis efectos RPG es compute, abrir con eso desorienta. Lo coloco como nota de breaking con un "no te afecta salvo compute" explícito. Prioricé la utilidad anti-stuck (docs y escéptico lo enmarcan igual) sobre el énfasis del veterano.

**Contradicción real resuelta — hit-flash multi-enemigo:** veterano y escéptico empujan fuerte `instance uniform`/`set_instance_shader_parameter`; docs lo menciona menos. El veterano y el escéptico además avisan del bug #83472 (instance uniform contamina el next_pass) — el escéptico añade el límite práctico de ~16 instance uniforms. Verifiqué ambos vía WebSearch (issue #83472 confirmado, límite 16 confirmado). Adjudico a favor del veterano/escéptico: el material compartido es EL bug de RPG real, así que lo promuevo a "patrón base de GDScript" en la sección, con la advertencia de #83472. Es el aporte de campo que separa una skill que funciona de una que copia tutoriales de 2023.

**Contradicción menor — stencil syntax:** docs marcó como "verificación pendiente" los keywords exactos; veterano y escéptico afirman `stencil_mode write, compare_always, 1;` / `read, compare_not_equal, 1;`. Verifiqué vía WebSearch: la sintaxis comma-separated y los comparadores están confirmados en ejemplos del release 4.5. Adjudico a favor de la sintaxis concreta, pero mantengo la jerarquía del escéptico/veterano: **primero el modo Outline nativo de StandardMaterial3D** (reuse-first, ponytail), shader de dos pases solo para X-ray. Esto resuelve también el "addon vs construir": las 3 coinciden en construir, pero la sección Stencil nativa es el "no escribas nada" que el ponytail exige.

**discard vs ALPHA_SCISSOR_THRESHOLD:** docs y escéptico/veterano coinciden — `discard` rompe early-Z y (docs aporta el matiz verificable) no castea sombra como `ALPHA_SCISSOR_THRESHOLD`. Mantengo `discard` para el dissolve de muerte (efímero, correcto) y la regla "no como recorte permanente". Sin contradicción.

**Depth no-lineal (agua):** solo el escéptico desarrolla la reconstrucción con `INV_PROJECTION_MATRIX` y el gotcha NDC OpenGL en Compatibility. Es nicho y de alto valor anti-stuck; lo incluyo. Las otras lentes no lo contradicen, solo lo omiten.

**Descartado por dudoso/no verificable:** las cadenas literales `Varyings cannot be passed for the 'in' qualifier` y `Fragment-stage varying could not be accessed` — el propio escéptico admite no haberlas verificado; uso solo `Varying must be assigned before using!` que sí está confirmado. También descarté afirmar una página de docs oficial dedicada a `stencil_mode` (docs admite que no existía publicada en el ciclo 4.5; la evidencia es release notes + ejemplos comunitarios).

**Web/Compatibility:** las 3 coinciden (sin C#, sin stencil, screen-space frágil). Consolidado en el paso 6 de decisión y en pitfalls. Es crítico para un RPG open-source que apunte a web.

## Fuentes

- https://github.com/godotengine/godot-docs/issues/11744
- https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html
- https://github.com/godotengine/godot/pull/70967
- https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html
- https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html
- https://docs.godotengine.org/en/stable/classes/class_standardmaterial3d.html
- https://godotshaders.com/shader/stencil-based-silhouette/
- https://godotengine.org/releases/4.5/
- https://github.com/godotengine/godot-proposals/issues/7174
- https://github.com/godotengine/godot/issues/83472
- https://github.com/godotengine/godot/issues/78945
- https://github.com/godotengine/godot/issues/76537
- https://godotengine.org/article/godot-40-gets-global-and-instance-shader-uniforms/
- https://github.com/godotengine/godot/issues/58924
- https://github.com/godotengine/godot/issues/67493
- https://github.com/godotengine/godot/issues/97728
- https://github.com/godotengine/godot/issues/79914
- https://github.com/godotengine/godot/issues/50464
- https://github.com/godotengine/godot/issues/33840
- https://github.com/godotengine/godot/issues/81391
- https://github.com/godotengine/godot/issues/115599
- https://godotshaders.com/shader/hit-flash-effect-shader/
- https://godotshaders.com/shader/dissolve-godot-4-x/
- https://godotshaders.com/shader/complete-toon-shader/
- https://godotshaders.com/shader/shield-shader-with-intersection-highlight/
- https://hexaquo.at/pages/understanding-godot-light-shaders-and-light-calculations-by-implementing-a-toon-light-shader/
- https://gameidea.org/2026/02/01/creating-a-stylized-3d-water-shader/
