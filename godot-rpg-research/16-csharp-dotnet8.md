## Notas de adjudicación

Las tres lentes (docs oficiales, veterano de campo, escéptico anti-stuck) coincidieron en el núcleo del tema con altísima consistencia, lo cual eleva la confianza:
- `partial` obligatorio + source generators → GD0001/GD0002.
- Sufijo `EventHandler` en delegates de señal → GD0201; retorno `void` → GD0203.
- Marshalling Variant: `Godot.Collections.Array/Dictionary<T>` en fronteras del engine, `System.Collections` solo interno; `[MustBeVariant]` en genéricos → GD0102/GD0202/GD0301/GD0302.
- `IsInstanceValid` en vez de comparar con `null`; `Dispose() != Free()`; `QueueFree` para nodos.
- async: revalidar tras cada `await`; `ToSignal` devuelve `SignalAwaiter` no `Task`.
- C# NO en web en 4.6; net8.0 obligatorio; NativeAOT experimental en móvil, sin cross-OS, sin espacios en el nombre del proyecto.
Todo esto se mantiene como hechos firmes.

### Dónde discreparon o hubo incertidumbre, y cómo lo adjudiqué

1. **Nombre del helper de emisión tipado.** El dossier "docs" mencionó solo `EmitSignal(SignalName.X, ...)`; "field" y "skeptic" afirmaron el helper `EmitSignalXxx(...)`. Una WebSearch al PR original (GH-68233) mostró el naming de la propuesta inicial (`OnMySignal`), pero la documentación de C# signals (4.4/stable) confirma que **lo que shippeó es `EmitSignal<NombreSeñal>(...)`** como wrapper tipado sobre `EmitSignal(SignalName.X, ...)`. Adjudicación: uso `EmitSignalHealthChanged(...)` en el ejemplo y menciono ambos. Confianza alta.

2. **Páginas individuales GDxxxx (mensajes verbatim).** Las tres lentes avisaron que `WebFetch` da 403 en `docs.godotengine.org` (lo reconfirmé: 403 tanto en `/en/4.6/.../diagnostics/index.html` como en `c_sharp_signals.html`). Los CÓDIGOS y sus causas son consistentes entre las tres lentes y coinciden con el set conocido del analizador `Godot.SourceGenerators`. Adjudicación: presento los códigos y causas como fiables (la página índice 4.6 existe y está versionada), pero traté los strings literales exactos como "verbatim aproximado" — no inventé ninguno que no apareciera en al menos dos lentes.

3. **"`[Export] Array` aparece vacío en el build exportado".** Afirmación SOLO de "field", con una única fuente de blog (bugnet.io). "docs" y "skeptic" no la corroboran. Adjudicación: la degradé de "hecho" a "check de verificación" (validar en build exportado real), sin presentarla como bug confirmado de 4.6.3.

4. **`dynamic` → AD0001 (MustBeVariantAnalyzer).** Solo "skeptic", con issue real GH-91345. Plausible y de bajo riesgo. Adjudicación: incluida como pitfall nicho con su issue, marcada como tal.

5. **Typed `Dictionary[K,V]` y nodos que no reflejan cambios (GH-97850).** "skeptic" lo señaló como comportamiento de versiones dev. Adjudicación: lo omití del cuerpo principal para no introducir ruido no confirmado en 4.6.3 stable; el caso de copia-vs-referencia (GH-42484) sí lo mantuve porque es comportamiento estable y bien documentado.

6. **GDTask vs `ToSignal`+CTS.** "field" recomienda GDTask; "docs"/"skeptic" muestran el patrón nativo con CTS. Adjudicación ponytail: patrón nativo por defecto, GDTask solo para secuencias serias — coherente con "no escribas/no añadas lo que no necesitas".

Prioricé siempre lo verificable en la rama 4.6 de las docs y descarté afirmaciones de una sola lente sin respaldo cruzado.

## Fuentes

- https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/diagnostics/index.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0001.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0102.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0201.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0202.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0301.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/diagnostics/GD0302.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_signals.html
- https://docs.godotengine.org/en/4.4/tutorials/scripting/c_sharp/c_sharp_signals.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_variant.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_collections.html
- https://github.com/godotengine/godot/pull/68233
- https://github.com/godotengine/godot/issues/58955
- https://github.com/godotengine/godot/issues/68411
- https://github.com/godotengine/godot/issues/70298
- https://github.com/godotengine/godot/issues/82268
- https://github.com/godotengine/godot/issues/86926
- https://github.com/godotengine/godot/issues/89105
- https://github.com/godotengine/godot/issues/91345
- https://github.com/godotengine/godot/issues/93608
- https://github.com/godotengine/godot/issues/95358
- https://github.com/godotengine/godot/issues/95813
- https://github.com/godotengine/godot/issues/102747
- https://github.com/godotengine/godot/issues/104268
- https://github.com/godotengine/godot/issues/107579
- https://github.com/godotengine/godot/issues/42484
- https://github.com/godotengine/godot/issues/70796
- https://github.com/godotengine/godot/pull/101006
- https://github.com/godotengine/godot-proposals/issues/11909
- https://github.com/godotengine/godot-docs/issues/9239
- https://godotengine.org/article/godotsharp-packages-net8/
- https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/
- https://forum.godotengine.org/t/godotobject-vs-refcounted-useless-in-c/109662
- https://forum.godotengine.org/t/could-not-resolve-sdk-godot-net-sdk-on-godot-4-2-2-with-c/57509
- https://chickensoft.games/blog/gdscript-vs-csharp
- https://patricktcoakley.com/blog/choosing-between-csharp-and-gdscript-in-godot/
- https://github.com/Fractural/GDTask
