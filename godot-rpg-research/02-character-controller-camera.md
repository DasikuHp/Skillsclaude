## Notas de investigación — Controlador de personaje + cámara 3ª persona (Godot 4.6)

### Verificaciones realizadas vía WebSearch (junio 2026)
- **SpringArm3D**: confirmado que castea rayo/forma por su eje −Z y mueve a sus hijos al punto de colisión con `margin` opcional. Propiedades verificadas: `spring_length` (extensión máxima, usada por raycast y shape-cast), `margin` (separa la `Camera3D` del punto exacto de colisión), `shape` (si se asigna, shape-cast en vez de raycast), `add_excluded_object(rid)` (excluye PhysicsBody3D por RID). Fuente: docs oficiales y SpringArm3D.xml en el repo.
- **CharacterBody3D**: confirmado que en Godot 4 `velocity` es propiedad y `move_and_slide()` no acepta argumento. `move_and_slide_with_snap()` eliminado → usar `floor_snap_length`. `get_gravity()` añadido en 4.4 (devuelve Vector). `floor_snap_length` ~1.0 da margen generoso para personajes 3D y `is_on_floor()` consistente en terreno irregular. Ejemplo práctico: `floor_max_angle = deg_to_rad(46.0)`, `floor_snap_length = 1.0`, `floor_stop_on_slope = true`.

### Hechos 4.6 aplicados
- Jolt es el motor 3D por defecto en proyectos 4.6 nuevos; CharacterBody3D + move_and_slide es lógica del árbol de escena y no cambia, pero step-up de escaleras sigue sin ser automático.
- Breaking 4.6 (GH-110767): propiedades de nombre de animación de AnimationPlayer (current_animation/assigned_animation/autoplay/get_queue/señal current_animation_changed) String→StringName; leerlas como string rompe a nivel de fuente.
- Typed dictionaries Dictionary[K,V] disponibles (no necesarios en este dominio concreto).

### Arquitectura
- Jerarquía: Player(CharacterBody3D) → CollisionShape3D + Visual(Node3D) + CameraPivot(Node3D) → SpringArm3D → Camera3D.
- Desacoplar yaw/pitch (en el pivote Node3D) de distancia/colisión (en SpringArm3D).
- Excluir el collider del Player del SpringArm con add_excluded_object(get_rid()); usar SphereShape3D radio ~0.3 para shape-cast suave.

### Pitfalls clave
- Gravedad solo en el aire; no resetear velocidad entera; move_and_slide sin argumento; SpringArm colapsa si no excluyes al Player; floor_snap_length corto causa despegue; deslizamiento parado en pendientes por floor_max_angle/floor_stop_on_slope; step-up no automático (proposals#2751); sumar event.relative; recompilar C# por StringName.

### Addons
- Phantom Camera (ramokz) para cámaras avanzadas/lock-on. Third Person Camera (asset 1815). Real Controller (asset 4494, específico 4.6). Third Person Controller (asset 3934, 4.4/4.5/4.6). GDQuest demo MIT como referencia. Para solo cámara, SpringArm3D nativo basta.

## Fuentes
- https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html
- https://docs.godotengine.org/en/stable/classes/class_springarm3d.html
- https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html
- https://github.com/godotengine/godot/blob/master/doc/classes/SpringArm3D.xml
- https://github.com/gdquest-demos/godot-4-3d-third-person-controller
- https://www.gdquest.com/news/2022/12/godot-4-third-person-controller/
- https://github.com/Jeh3no/Godot-Third-Person-Controller/
- https://github.com/selgesel/godot4-third-person-controller
- https://github.com/SHawkeye77/Platformer3D3rdPerson
- https://github.com/ramokz/phantom-camera
- https://github.com/godotengine/godot/issues/71993
- https://github.com/godotengine/godot-proposals/issues/2751
- https://codingquests.io/blog/godot-4-3d-character-controller-tutorial
- https://www.gdquest.com/library/character_movement_3d_platformer/
- https://kidscancode.org/godot_recipes/4.x/3d/characterbody3d_examples/index.html
- https://supermatrix.studio/blog/camera-controller-and-spring-arm-3d-in-godot
- https://yosoyfreeman.github.io/article/godot/tutorial/achieving-better-mouse-input-in-godot-4-the-perfect-camera-controller/
- https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot
- https://godotengine.org/asset-library/asset/1815
- https://godotengine.org/asset-library/asset/4494
- https://godotengine.org/asset-library/asset/3934
- https://godotassetlibrary.com/asset/TfH9f6/thirdperson-controller-(.net)
