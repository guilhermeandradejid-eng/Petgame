shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// bolha do escudo: borda brilhante (fresnel) + hexágonos correndo
uniform float fade = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec2 h = UV * vec2(18.0, 9.0) + vec2(0.0, TIME * 1.5);
	vec2 g = abs(fract(h) - 0.5);
	float hex = smoothstep(0.42, 0.48, max(g.x * 1.15 + g.y * 0.6, g.y * 1.2));
	vec3 c = vec3(0.3, 0.75, 1.0);
	ALBEDO = c * (f * 1.8 + hex * 0.35 + 0.05) * fade * (0.85 + 0.15 * sin(TIME * 12.0));
}
