# Godot 4.6 — Rendering & Visuals (research agent output)

## Renderers
- Forward+ (Vulkan/D3D12/Metal): desktop best. SDFGI/VoxelGI, volumetric fog, SSR, SSIL, SSS, PCSS, TAA/FSR2. 512 lights/cluster.
- Mobile: mobile/XR. LightmapGI + ReflectionProbe only. 8 lights/mesh. No SDFGI/VoxelGI/SSIL/volumetric fog. FSR1 only.
- Compatibility (OpenGL/WebGL2): only web option. LightmapGI baked tier. No real-time GI/SSR/SSAO.
- [4.6] D3D12 default driver on Windows for new projects (Agility SDK 613→618). Metal backend for Apple.

RPG: desktop=Forward+; mobile=Mobile (lightmap+probe); web=Compatibility (baked).

## Global Illumination
- LightmapGI: baked static, highest accuracy, ~free runtime, all renderers. Dungeons. bake_mode/quality/bounces/directional. lightmap probes for dynamic chars. LIGHT_BAKE_DYNAMIC.
- VoxelGI: real-time, emitters contribute, F+ only, bake seconds, watch light leaks. subdiv 64/128/256/512. Small dynamic rooms.
- SDFGI: semi real-time, infinite cascaded, F+ only, no bake, day-night/moving sun. Open world. sdfgi_cascades(6), sdfgi_min_cell_size, sdfgi_use_occlusion, sdfgi_read_sky_light. Pair with ReflectionProbe/SSR for specular.
- ReflectionProbe: local cubemap, all renderers, lowest cost.
- SSIL: real-time screen-space, F+ only, half-res default.
- [4.6] Lightmapper: OIDN 2.3 denoiser, adaptive sampling [unverified], better UV2 packing, bakes sky/env light. Reflection/radiance probes now OCTAHEDRAL maps (cheaper/less memory). Caveat: rendering regression godot#115599 (sky shaders + VoxelGI/SDFGI) in some 4.6 builds — check patch.

## SSR [4.6 overhaul, PR #111210, Hi-Z tracing, F+ only]
- Hi-Z hierarchical depth ray marching, default 64 max steps.
- Half-res (new default, 3-4x faster, bilateral upscale) vs full-res.
- Roughness via gaussian-blurred mip chain (no quality knob).
- Samples previous frame (reprojection). No motion vectors yet (fast objects artifact).
- ssr_depth_tolerance default 0.2→0.5. Props: ssr_enabled, ssr_max_steps, ssr_fade_in/out, ssr_depth_tolerance.

## LOD / Visibility / Occlusion (GeometryInstance3D)
- Mesh LOD auto-generated on import. rendering/mesh_lod/lod_change/threshold_pixels, per-mesh lod_bias.
- Visibility ranges (HLOD): visibility_range_begin/end + margins (hysteresis) + visibility_range_fade_mode (Disabled/Self/Dependencies). Town skyline, terrain chunks.
- OccluderInstance3D → bake → Occluder3D resource. Best indoors with no DirectionalLight3D shadows (dungeons). Open world prefers LOD+visibility ranges.

## Lighting/Shadows/Fog/Environment
- DirectionalLight3D: PSSM 4 splits, blend_splits, directional_shadow_max_distance/fade_start. light_angular_distance>0 = PCSS soft shadows (sun ~0.5°). 8 dir lights max.
- OmniLight3D: omni_range/attenuation, omni_shadow_mode (DualParaboloid/Cube). light_size>0 = area shadows.
- SpotLight3D: spot_range/angle/angle_attenuation. angle>89° disables shadows.
- Common: light_energy, light_indirect_energy, light_specular, light_cull_mask, shadow_bias/normal_bias, distance_fade, projector textures.
- light_bake_mode: DISABLED/STATIC/DYNAMIC.
- Volumetric fog (F+): volumetric_fog_enabled/density/albedo/emission/gi_inject (VoxelGI/SDFGI only, ignores Lightmap). FogVolume nodes (box/ellipsoid/cone/custom shader) for dungeon mist. [4.6] more physical blending = brighter, lower density to compensate.
- Tonemap: Linear/Reinhard/Filmic/ACES/AgX (newest, best realism). tonemap_exposure/white.
- Glow (F+/Mobile): 7 levels. [4.6] runs before tonemapping, Screen blend default, faster mobile. Default changes: blend Soft Light→Screen (brighter), glow_intensity 0.8→0.3.
- SSAO (F+/Mobile), SSIL (F+ only half-res). Sky roughness_layers 8→7.

## Materials/Shaders
- StandardMaterial3D/ORMMaterial3D: transparency (Disabled/Alpha/AlphaScissor/AlphaHash/DepthPrePass), shading (PerPixel/PerVertex/Unshaded), PBR (albedo/metallic/roughness/emission/normal/ao), advanced (heightmap/parallax, SSS F+ only, rim, clearcoat, anisotropy, refraction, detail), effects (billboard, grow outline, proximity_fade, distance_fade, cull_mode, next_pass). Stencil (4.5+): outlines, x-ray silhouette through walls (enemy highlight).
- Shader lang GLSL-ES3-like. spatial/canvas_item/sky/fog/particles. vertex/fragment/light. Built-ins ALBEDO/METALLIC/ROUGHNESS/EMISSION/NORMAL_MAP/ALPHA/UV/TIME/SCREEN_UV/DEPTH. ShaderMaterial. VisualShader node graph.
- [4.6 breaking] SceneData view_matrix/inv_view_matrix mat4→mat3x4: custom 3D shaders must transpose.

## VFX/crowds
- Decal node: projected albedo/normal/ORM/emission. Blood, scorch, runes. F+/Mobile.
- GPUParticles3D + ParticleProcessMaterial: sub-emitters (fireball→sparks), trails (RibbonTrailMesh/TubeTrailMesh sword swipe), attractors (Box/Sphere/VectorField3D vortex), collision (Box/Sphere/HeightField/SDF3D), turbulence. draw_passes(4), set visibility_aabb on moving emitters. CPUParticles3D fallback web.
- MultiMeshInstance3D + MultiMesh: one draw call thousands. Grass, foliage, crowds, arrow volleys. INSTANCE_CUSTOM per-instance. Combine visibility ranges + LOD.

## RPG render presets
- Desktop open-world: Forward+, SDFGI + ReflectionProbes + half-res SSR, AgX, PCSS sun, volumetric fog, FSR2.
- Desktop dungeon: Forward+, LightmapGI (+VoxelGI dynamic rooms), OccluderInstance3D, FogVolumes.
- Mobile: Mobile, LightmapGI+ReflectionProbe, no real-time GI, 8 lights/mesh.
- Web: Compatibility, LightmapGI baked, lean post-FX.
