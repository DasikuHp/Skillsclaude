shader_type spatial;
render_mode cull_disabled; // ver interior al disolver

uniform sampler2D albedo_tex : source_color;
uniform sampler2D noise : hint_default_white; // NoiseTexture2D seamless
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec3 edge_color : source_color = vec3(1.0, 0.4, 0.0);

void fragment() {
	float n = texture(noise, UV).r;
	// discard es correcto para un efecto efimero de muerte.
	// NO lo uses como recorte permanente (rompe early-Z): usa ALPHA_SCISSOR_THRESHOLD.
	if (n < dissolve) discard;
	ALBEDO = texture(albedo_tex, UV).rgb;
	float edge = smoothstep(dissolve, dissolve + edge_width, n);
	EMISSION = edge_color * (1.0 - edge) * 4.0; // borde incandescente
}
