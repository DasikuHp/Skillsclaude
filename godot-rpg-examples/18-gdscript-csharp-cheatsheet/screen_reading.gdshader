// Godot 3 usaba SCREEN_TEXTURE / DEPTH_TEXTURE como built-ins.
// PR #70967 los ELIMINO. En 4.6 son uniforms con hint.
// Error si usas el built-in crudo: 'Use of reserved keyword'.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex  : hint_depth_texture;

void fragment() {
    vec4 behind = texture(screen_tex, SCREEN_UV);
    COLOR = vec4(1.0 - behind.rgb, 1.0);   // invertir lo que hay detras
}
// Aviso anti-stuck: screen/depth dan textura negra/vacia en Compatibility/web (GH-97728).
// "Compila" NO implica "funciona": prepara fallback si exportas a web.
