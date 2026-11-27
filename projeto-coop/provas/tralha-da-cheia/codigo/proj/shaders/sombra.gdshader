// Sombra de contato: elipse de borda recortada que multiplica por uma tinta (nunca preto). Base no Compatibility.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mul, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 shadow_tint : source_color = vec3(0.6, 0.54, 0.7);
uniform float forca = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = length(p) - 0.06 * sin(a * 5.0) * 0.5;
	float m = step(e, 0.82);
	ALBEDO = mix(vec3(1.0), shadow_tint, m * forca);
}
