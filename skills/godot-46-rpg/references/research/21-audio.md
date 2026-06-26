## Notas de adjudicación (tema #19 Audio)

Los tres dossiers coinciden en lo esencial (modelo dB, autoload para música persistente, fallback silencioso de bus a Master, pool vs polifonía, loop en `.import`). Discrepancias resueltas:

1. **`volume_linear` / `set_bus_volume_linear`.** El escéptico afirmó que `AudioStreamPlayer.volume_linear` existe en 4.6; docs y veterano mencionaron `set_bus_volume_linear` (4.5+) con un "verifica en tu build". **Verificado vía WebSearch:** la doc oficial stable de `AudioStreamPlayer` lista `volume_linear` (0..1, convertido a `volume_db`). Lo incluí como ruta recomendada anti-error, conservando también `linear_to_db` para quien prefiera dB. Adjudicado a favor del escéptico, con confirmación.

2. **`AudioEffectCompressor.sidechain` — tipo.** Docs lo describía como "propiedad sidechain seteada al nombre del bus"; escéptico lo trató como `StringName` referenciado por nombre. **Verificado vía WebSearch:** la doc oficial confirma `sidechain` es `StringName` (nombre de bus). Mantenido el caveat GH-16036 (routing bugoso) y la recomendación de Tween manual como opción que no se atasca.

3. **`INVALID_ID` valor.** El escéptico escribió "INVALID_ID (0)"; docs y veterano usan la constante `AudioStreamPlaybackPolyphonic.INVALID_ID` sin afirmar valor numérico. Adjudiqué a favor de usar SIEMPRE la constante nombrada (no el literal 0), que es lo idiomático y no depende de un valor que no verifiqué.

4. **`finished` y polifonía.** El veterano aportó el matiz más útil (GH-88941: el polifónico NO emite `finished` por stream; GH-102479: clip con loop nunca emite `finished` → acumulación de nodos con `queue_free`). Esto resuelve cuándo elegir pool-de-nodos vs polifónico: lo integré como criterio de decisión explícito, que docs no daba.

5. **Crossfade: 2 players vs clases nativas.** Los tres concuerdan: para 2 temas, `Tween` sobre `volume_db` con dos players basta; `AudioStreamInteractive` solo si el compositor entrega la transition table. El veterano y escéptico advierten que anidar `Interactive`+`Synchronized` es frágil (desync por beat). Mantenido como recomendación práctica.

6. **Pitfall `volume_db = 0.5`.** El escéptico se contradijo a sí mismo en su propio texto (primero "inaudible", luego se corrige a "casi 0 dB"). Usé la versión correcta de docs/veterano: +0.5 dB ≈ casi imperceptible, NO mitad de volumen.

7. **Listener 3D.** Veterano y escéptico lo aportan (la `Camera3D` activa es listener por defecto; `AudioListener3D` requiere `make_current()`). Docs no lo cubría. Integrado como sonda anti-stuck de "audio sin dirección".

8. **C# property path en Tween.** El escéptico aportó el detalle de que `TweenProperty` usa snake_case `"volume_db"` aunque la propiedad C# sea `VolumeDb`. Verosímil y consistente con el modelo de propiedades del motor; conservado como pitfall C#. Los ejemplos C# usan ese string snake_case.

9. **`loop_offset` y pop.** Docs (GH-64775) y veterano coinciden: `loop_offset > 0` puede producir click. Mantenido `loop_offset=0.0` como default seguro.

No incluí ninguna API ni URL que no apareciera en al menos un dossier o que no verificara. Descartado: cualquier afirmación de valor numérico de `INVALID_ID`.

## Fuentes

- https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html
- https://docs.godotengine.org/en/stable/classes/class_audioserver.html
- https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreampolyphonic.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamplaybackpolyphonic.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html
- https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html
- https://github.com/godotengine/godot/issues/42671
- https://github.com/godotengine/godot/issues/88941
- https://github.com/godotengine/godot/issues/102479
- https://github.com/godotengine/godot/issues/16036
- https://github.com/godotengine/godot/issues/83797
- https://github.com/godotengine/godot/issues/109728
- https://github.com/godotengine/godot/issues/64775
- https://www.gdquest.com/tutorial/godot/audio/background-music/
- https://kidscancode.org/godot_recipes/4.x/audio/audio_manager/index.html
