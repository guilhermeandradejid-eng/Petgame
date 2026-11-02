// Safe-mode stand-in for glow.gdshader.
shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
void fragment() {
	ALBEDO = color.rgb;
}
