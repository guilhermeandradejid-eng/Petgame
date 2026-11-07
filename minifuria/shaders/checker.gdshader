shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 c = floor(UV * vec2(16.0, 2.0));
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(vec3(0.95), vec3(0.08), k);
	ROUGHNESS = 0.8;
}
