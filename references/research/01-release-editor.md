# Godot 4.6 — Release & Editor (research agent output)

Released 2026-01-27, theme "It's all about your flow". Minor release, light migration. Latest patch 4.6.3.

## New features 4.6 vs 4.5
### Physics
- Jolt default 3D physics for NEW projects (physics/3d/physics_engine). Existing keep GodotPhysics3D. Fixed ghost collisions segment_intersects_convex (GH-106084).

### IK suite (built on SkeletonModifier3D) — IKModifier3D base + solvers:
- TwoBoneIK3D (deterministic, arms/legs), SplineIK3D (deterministic, tails/spine/tentacles), FABRIK3D, CCDIK3D, JacobianIK3D (iterative), ChainIK3D, IterateIK3D (has Deterministic option GH-112524).
- Support: BoneTwistDisperser3D (GH-113284), LimitAngularVelocityModifier3D (GH-111184). LookAt/AimModifier3D gained Relative option (GH-111367).
- Staged: 4.4 added SkeletonModifier3D + LookAtModifier3D/RetargetModifier3D; 4.5 added SpringBoneSimulator3D + BoneConstraint3D (AimModifier3D/ConvertTransformModifier3D/CopyTransformModifier3D); 4.6 completes IK.

### Rendering: SSR rewrite (Hi-Z), glow rewrite, brighter volumetric fog, D3D12 default Windows.

### Editor/Workflow
- Modern theme default (Classic still available), grayscale option.
- Unified docking: bottom panels now docks, draggable to any side, floatable into separate windows (multimonitor). Debugger can't float.
- Select-only mode decoupled from Transform mode. Default reverted to Transform (GH-113458).
- GridMap Bresenham line painting (GH-105292).

### Scene/Project
- Nodes have unique internal ID — refs survive renames/reparenting; connections preserved. .tscn stores unique IDs.
- .tscn load_steps no longer written. Run Project>Tools>Upgrade Project Files before committing (big diffs otherwise).
- Patch/update export files contain only changed parts of resources (smaller updates).

### LibGodot: embed engine as library in host app.

### Navigation
- NavigationServer backend selection + Dummy backend (disable nav without recompile).
- AStar2D/3D.get_point_path, AStarGrid2D.get_id_path/get_point_path return EMPTY when source point disabled/solid (guard callers).

### Profiling/Debug
- External profiler: Tracy (documented), Perfetto, Apple Instruments. GDScript/C#/GDExtension.
- Script debugger "Step Out" button (PR #97758).
- ObjectDB Profiling Tool (GH-97210).

### Animation
- Animation.interpolate_via_rest() static (GH-107423). Insert keys at time vs cursor (GH-107511). Go to next/prev keyframe. AnimationLibrary serialization no longer Dictionary (GH-110502). Branching ping-pong separate time/delta (GH-112047).

## Breaking changes 4.5→4.6 (few; mostly safe)
### Visual (likely to bite)
- Glow defaults: glow_blend_mode 2(SoftLight)→1(Screen) brighter; glow_intensity 0.8→0.3; glow_levels changed. New-resource defaults; existing keep stored.
- ssr_depth_tolerance 0.2→0.5. Volumetric fog brighter. sky_reflections/roughness_layers 8→7. PopupMenu.submenu_popup_delay 0.3→0.2.
### Shaders (silent)
- SceneData view_matrix/inv_view_matrix mat4→mat3x4: transpose ops in GLSL. (docs gap issue #11744)
### Core
- FileAccess.create_temp mode_flags int→ModeFlags. FileAccess.get_as_text skip_cr param REMOVED. Performance.add_custom_monitor optional type param.
### Animation API (C# recompile)
- AnimationPlayer: assigned_animation/autoplay/current_animation String→StringName; get_queue StringName[]; current_animation_changed name→StringName.
### 3D
- MeshInstance3D.skeleton default NodePath("..")→NodePath("") (compat available).
- SpringBoneSimulator3D enum types moved to SkeletonModifier3D.*.
### Networking
- StreamPeerTCP disconnect_from_host/get_status/poll → StreamPeerSocket. TCPServer is_connection_available/is_listening/stop → SocketServer.
### Android export: src/→src/main/java/, manifest/assets under src/main/.

## Maintenance
- 4.6.1: NodePath hash fix, AnimationTree/Blend Tree use-after-free crashes, LookAt/AimModifier3D forward-vector fix, SoftBody3D total_mass, Jolt transform updates, sky no Sky resource.
- 4.6.2: 122 fixes. 3D subgizmo focus, DirectionalLight3D property list, autocomplete fix.
- 4.6.3: 86 fixes. SplineIK crashes fixed, GridMap paste rotation, RefCounted::unreference race, Object signal thread-safety, LightmapGI probe update Compatibility, per-mesh 3D light GLES3/Mobile, iOS exports.

## RPG highlights
- IK suite: foot placement, look-at, weapon aiming, procedural limbs. (SplineIK crashes fixed 4.6.3; LookAt/Aim forward-vector fixed 4.6.1.)
- Jolt default = better large-world stability. Nav backend selection/Dummy. Guard get_point_path empty returns.
- SSR rewrite half-res. Unique node IDs (safe refactors). GridMap Bresenham. Step Out + Tracy/Perfetto. Smaller patch exports.
- Migration watch: glow brighter (re-tune), GLSL view_matrix mat3x4, AnimationPlayer StringName (C# recompile), Android source-set.

## CAVEAT
- GDScript @abstract shipped in 4.5 NOT 4.6 — do not attribute to 4.6. (My skill currently says "desde 4.5" — correct.)
