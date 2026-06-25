shader_type spatial;
render_mode cull_disabled;

// SCREEN_TEXTURE/DEPTH_TEXTURE fueron ELIMINADOS como built-ins en Godot 4.
// Se declaran como uniforms con hint:
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float foam_distance : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	// El depth crudo es NDC no-lineal, NO metros. Hay que reconstruir profundidad de vista.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	// En Compatibility (NDC OpenGL) ndc.z puede necesitar: raw * 2.0 - 1.0
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float surface_depth = -((INV_PROJECTION_MATRIX * vec4(0.0, 0.0, FRAGCOORD.z * 2.0 - 1.0, 1.0)).z);
	float diff = scene_depth - surface_depth;
	float foam = 1.0 - smoothstep(0.0, foam_distance, diff);
	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, foam_color, foam);
	ALPHA = 0.85;
}
