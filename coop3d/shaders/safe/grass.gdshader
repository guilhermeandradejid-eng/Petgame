// Safe-mode stand-in for grass.gdshader (no wind, no global uniforms).
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec4 root_color : source_color = vec4(0.25, 0.55, 0.26, 1.0);
uniform vec4 tip_color : source_color = vec4(0.72, 0.93, 0.45, 1.0);
void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, 1.0 - UV.y);
}
