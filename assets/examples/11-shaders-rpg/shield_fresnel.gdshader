shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;
// Va tipicamente como Material.next_pass del personaje.

uniform vec3 shield_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	// El built-in es VIEW (NO VIEW_DIR). En view space; normaliza tras interpolar.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), power);
	ALBEDO = shield_color;
	EMISSION = shield_color * fres * 3.0;
	ALPHA = fres;
}
