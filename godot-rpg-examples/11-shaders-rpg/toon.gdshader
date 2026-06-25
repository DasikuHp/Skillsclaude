shader_type spatial;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D ramp : hint_default_white; // gradiente de bandas, filter_nearest

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
}

void light() {
	// light() corre UNA VEZ POR LUZ POR PIXEL.
	// Usar '=' aqui borra las luces anteriores -> solo se ve la ultima. Usa '+='.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = texture(ramp, vec2(ndl, 0.0)).r; // bandas controlables por arte
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
