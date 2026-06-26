## Adjudicación entre las 3 lentes

**Contradicción mayor — ¿GDExtension funciona en web?**
- El *veterano* afirmó tajante: "El export web NO soporta GDExtension" (citando un hilo de foro de 2024 y que Terrain3D solo targetea PC/Android).
- *Docs* y *escéptico* dijeron: funciona, pero con caveats severos (thread-mode debe casar, dlink, Emscripten, COOP/COEP).
- **Verifiqué vía WebSearch** (GH godot/issues #95077, #94537, #82865, #105717 y docs "exporting_for_web"): el `.gdextension` soporta claves `web.debug.threads.wasm32` / `web.release.wasm32`, y los propios issues describen *cómo* hacerlo funcionar (no que sea imposible). **Adjudicación: la posición docs/escéptico es la correcta.** GDExtension SÍ funciona en web en 4.6, pero es frágil. La afirmación absoluta del veterano se descarta como demasiado fuerte; conservo su matiz útil (Terrain3D/GodotSteam de facto targetean PC/Android, y conviene feature-flag con fallback GDScript si web es target serio). El punto en el que las 3 lentes SÍ coinciden y es 100% correcto: **C# no corre en web** (renderer Compatibility).

**Contradicción menor — causa del error "No GDExtension library found".**
- Solo el *escéptico* aportó la causa sutil: `compatibility_minimum` sin comillas produce ese error engañoso. **Verificado** en GH godot-docs #7864. Lo elevo a pitfall destacado porque es exactamente el tipo de trampa silenciosa donde una IA headless se atasca (el mensaje culpa al OS/arch, no a la sintaxis). Las otras causas (formato de claves, lib ausente) las aporta docs/escéptico y se conservan.

**Convergencias (alta confianza, conservadas):**
- Los 3 coinciden en la regla de altitud (GDScript tipado → C# → C++ solo hot path/wrap lib) y en reservar GDExtension para hot loops perfilados o envolver libs. Núcleo de la sección.
- Los 3 dan la misma anatomía de 4 archivos, los mismos no-negociables (`entry_symbol`==función `extern "C"`, `GDCLASS`, `_bind_methods`, nivel SCENE) y los mismos comandos SCons. Sin conflicto; consolidado.
- Pitfalls de error literal (Win32/Error 126/GLIBCXX/Android ABI/ABI mismatch/hot-reload frágil/Release-only) aparecen consistentes en al menos 2 lentes con issues reales; conservados con fix.

**Aportes únicos integrados:**
- *Veterano*: trampa C# no puede llamar GDExtension (sandwich C#→GDScript→C++); template oficial con CI; `use_static_cpp`/precisión double; referencias Terrain3D/GodotSteam como addons canónicos.
- *Escéptico*: `compatibility_minimum` quotes; `GDREGISTER_ABSTRACT/VIRTUAL_CLASS`; comandos headless de desatasque concretos; Firefox vs Chromium en web.
- *Docs*: tabla GDExtension vs módulo; `--dump-extension-api` para builds custom; niveles de init CORE/SERVERS/SCENE/EDITOR.

**Descartado/atenuado:**
- "Web no soporta GDExtension" (veterano) — refutado por verificación.
- Cifras de rendimiento específicas ("~59% más rápido tipado", "~16% usan C#") — las dejo fuera del cuerpo como números duros y las generalizo ("notablemente más rápido", "minoría usa C#") para no anclar a una encuesta puntual no re-verificada en esta sesión.

## Fuentes
- https://docs.godotengine.org/en/4.6/tutorials/scripting/gdextension/gdextension_c_example.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/gdextension_cpp_example.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/build_system/scons.html
- https://docs.godotengine.org/en/stable/classes/class_gdextension.html
- https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html
- https://github.com/godotengine/godot-cpp
- https://github.com/godotengine/godot-cpp-template
- https://github.com/godotengine/godot-docs/issues/7864
- https://github.com/godotengine/godot/issues/105615
- https://github.com/godotengine/godot/issues/95077
- https://github.com/godotengine/godot/issues/94537
- https://github.com/godotengine/godot/issues/82865
- https://github.com/godotengine/godot/issues/105717
- https://github.com/godotengine/godot/issues/111673
- https://github.com/godotengine/godot/issues/87761
- https://github.com/godotengine/godot/issues/86206
- https://github.com/godotengine/godot/issues/66231
- https://github.com/godotengine/godot/issues/88845
- https://github.com/godotengine/godot-cpp/issues/905
- https://github.com/godotengine/godot-cpp/issues/1459
- https://github.com/godotengine/godot-cpp/issues/1589
- https://github.com/godotengine/godot-cpp/issues/1849
- https://github.com/flathub/org.godotengine.Godot/issues/127
- https://godotengine.org/article/introducing-gd-extensions/
- https://chickensoft.games/blog/gdscript-vs-csharp
- https://godotsteam.com/howto/gdextension/
- https://godot-rust.github.io/book/toolchain/export-web.html
