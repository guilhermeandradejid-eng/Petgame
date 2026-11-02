// Safe-mode stand-in for cloud_sea.gdshader.
shader_type spatial;
render_mode unshaded;
uniform vec4 top_color : source_color = vec4(1.0, 0.97, 0.97, 1.0);
void fragment() {
	ALBEDO = top_color.rgb;
}
