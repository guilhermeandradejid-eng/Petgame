// Safe-mode stand-in for terrain.gdshader.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 grass_a : source_color = vec4(0.42, 0.78, 0.33, 1.0);
uniform vec4 rock_a : source_color = vec4(0.74, 0.55, 0.43, 1.0);
uniform float grass_only = 0.0;
void fragment() {
	float g = max(smoothstep(0.4, 0.7, NORMAL.y), grass_only);
	ALBEDO = mix(rock_a.rgb, grass_a.rgb, g);
}
