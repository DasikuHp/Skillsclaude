## Notas de investigación — Domain #2: Animación / AnimationTree / IK (Godot 4.6)

### Verificaciones hechas (WebSearch + WebFetch sobre XML de doc/classes en master)

Las páginas `docs.godotengine.org/.../classes/*` devolvieron HTTP 403 vía WebFetch tras el proxy, así que verifiqué contra el **XML fuente autoritativo** en `raw.githubusercontent.com/godotengine/godot/master/doc/classes/`.

**CORRECCIÓN IMPORTANTE al dossier**: el dossier asumía que `TwoBoneIK3D` expondría propiedades planas (`target_node`, `pole_node`). FALSO. La API real es **por índice sobre `setting_count`** (un modificador resuelve N cadenas):
- `TwoBoneIK3D` hereda de `IKModifier3D`. Propiedad propia: `setting_count: int = 0`.
- Setters/getters por índice: `set_root_bone(i)/set_root_bone_name(i, String)`, `set_middle_bone_name(i, String)`, `set_end_bone_name(i, String)`, `set_target_node(i, NodePath)`, `set_pole_node(i, NodePath)`, `set_pole_direction(i, SecondaryDirection)`, `set_pole_direction_vector(i, Vector3)`, `set_end_bone_direction`, `set_extend_end_bone(i, bool)`, `set_use_virtual_end(i, bool)`, `is_using_virtual_end(i)`, `get_end_bone_length(i)`.
- Fuente: TwoBoneIK3D.xml.

**IKModifier3D**: hereda de `SkeletonModifier3D`. Es "node for inverse kinematics that can modify multiple bones", base de los solvers. Propiedad propia: `mutable_bone_axes: bool = true` (recalcula ejes del bone pose cada frame; off = usa rest pose cacheada, más rápido). Métodos: `clear_settings()`, `get_setting_count()`, `reset()`, `set_setting_count(count)`.

**FABRIK3D**: hereda de `IterateIK3D` (no directamente de IKModifier3D). "position based forward and backward reaching IK solver". Genera zig-zag cuando el target está cerca de la raíz.

**LookAtModifier3D**: hereda de `SkeletonModifier3D` (one-bone). Props verificadas: `bone_name: String = ""`, `bone: int = -1`, `target_node: NodePath`, `forward_axis` (BoneAxis, default 4), `primary_rotation_axis` (default 1), `origin_from` (default ORIGIN_FROM_SELF), `origin_bone_name`, `origin_external_node`, `origin_offset: Vector3`, `use_angle_limitation: bool = false`, `use_secondary_rotation: bool = true`, `duration: float = 0.0`, `relative: bool = false`, `symmetry_limitation`.

**AnimationTree**: hereda de `AnimationMixer` en 4.6. Props: `tree_root` (AnimationRootNode), `anim_player` (NodePath), `advance_expression_base_node` (NodePath). Los métodos root motion NO están en AnimationTree sino heredados de AnimationMixer.

**AnimationMixer** (padre): `get_root_motion_position() -> Vector3`, `get_root_motion_rotation() -> Quaternion`, `get_root_motion_rotation_accumulator() -> Quaternion`, `get_root_motion_scale() -> Vector3`, `get_root_motion_position_accumulator() -> Vector3`. Props: `root_motion_track` (NodePath), `root_motion_local` (bool=false), `active` (bool=true), `callback_mode_process` (enum, default IDLE=1).

**AnimationNodeStateMachinePlayback** (firmas exactas verificadas):
- `travel(to_node: StringName, reset_on_teleport: bool = true) -> void`
- `start(node: StringName, reset: bool = true) -> void`
- `stop() -> void`
- `get_current_node() const -> StringName`
- `get_travel_path() const -> StringName[]`
- `is_playing() const -> bool`
- `get_current_play_position() const -> float`

### Confirmaciones de los hechos del dossier
- 7 solvers IK + jerarquía (FABRIK3D : IterateIK3D) confirmados.
- StringName en propiedades de nombre de animación de AnimationPlayer (breaking 4.6, GH-110767): coherente con que las firmas de SM playback ya devuelven/aceptan StringName.
- Root motion accumulator para evitar bug de rotación incremental: el método existe (verificado).

## Fuentes

- https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- https://godotengine.org/releases/4.6/
- https://github.com/godotengine/godot/blob/master/doc/classes/TwoBoneIK3D.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/IKModifier3D.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/FABRIK3D.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/LookAtModifier3D.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/AnimationTree.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/AnimationMixer.xml
- https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/AnimationNodeStateMachinePlayback.xml
- https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html
- https://docs.godotengine.org/en/latest/classes/class_twoboneik3d.html
- https://docs.godotengine.org/en/latest/classes/class_ikmodifier3d.html
- https://docs.godotengine.org/en/4.6/tutorials/animation/animation_tree.html
- https://github.com/godotengine/godot/pull/110120
- https://github.com/godotengine/godot-proposals/discussions/9885
- https://github.com/godotengine/godot/issues/93821
- https://github.com/godotengine/godot/issues/95688
- https://github.com/godotengine/godot/issues/62576
- https://github.com/godotengine/godot/issues/64171
- https://github.com/godotengine/godot/issues/89244
- https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html
- https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter
- https://store.godotengine.org/asset/andicraft/inverse-kinematics-example/
- https://forum.godotengine.org/t/which-godot-4-6-ik-solver-is-best-for-player-pose-tracking-fabrik-vs-twobone-vs-ccd/129191
- https://github.com/godotengine/awesome-godot
- https://gamefromscratch.com/inverse-kinematics-ik-return-to-godot/
- https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html
