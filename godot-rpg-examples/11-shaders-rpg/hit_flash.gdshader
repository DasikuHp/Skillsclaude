shader_type spatial;
render_mode cull_back; // sin discard => no rompe early-Z

// 'instance uniform' permite datos por-MeshInstance3D compartiendo el mismo recurso.
// Limite practico ~16 instance uniforms por shader.
// OJO WEB: 'instance uniform' NO esta soportado en el renderer Compatibility
// (= export web). Ahi este shader NO compila y el material no se renderiza
// (godot-proposals#6909). Para web, cambia la linea a:
//     uniform float flash : hint_range(0.0, 1.0) = 0.0;
// y duplica el ShaderMaterial por enemigo (resource_local_to_scene = true)
// usando set_shader_parameter en vez de set_instance_shader_parameter.
uniform sampler2D albedo_tex : source_color;
uniform vec3 flash_color : source_color = vec3(1.0);
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(base, flash_color, flash);
	// EMISSION para que el flash brille con glow (mas intenso en 4.6).
	EMISSION = flash_color * flash * 2.0;
}
