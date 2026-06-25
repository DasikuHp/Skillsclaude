// PASE 2: va en el Next Pass del material base.
// El material base escribe el stencil con: stencil_mode write, compare_always, 1;
// (Para outline simple, prueba primero la seccion Stencil->Outline nativa de
//  StandardMaterial3D: cero codigo. Esto es para X-ray a traves de paredes.)
// stencil_mode NO existe en el renderer Compatibility (web): fallback a casco invertido.
shader_type spatial;
render_mode depth_test_disabled, depth_draw_never, cull_front, unshaded;
stencil_mode read, compare_not_equal, 1;

uniform vec3 outline_color : source_color = vec3(1.0, 0.8, 0.0);

void fragment() {
	ALBEDO = outline_color;
}
