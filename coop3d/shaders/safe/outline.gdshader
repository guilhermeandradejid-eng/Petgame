// Safe-mode stand-in for outline.gdshader (constant-width hull).
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 outline_color : source_color = vec4(0.16, 0.09, 0.2, 1.0);
uniform float width = 0.012;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = outline_color.rgb;
}
