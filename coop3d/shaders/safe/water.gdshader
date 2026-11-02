// Safe-mode stand-in for water.gdshader (no depth texture, no waves).
shader_type spatial;
render_mode cull_disabled, blend_mix, specular_toon;
uniform vec4 shallow : source_color = vec4(0.35, 0.85, 0.9, 1.0);
uniform float fall = 0.0;
void fragment() {
	ALBEDO = shallow.rgb;
	ROUGHNESS = 0.2;
	ALPHA = 0.85;
}
