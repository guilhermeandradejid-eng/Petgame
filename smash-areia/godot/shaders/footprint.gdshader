// Pegadas e marcas na areia (MultiMesh): oval escuro e macio que some com o tempo
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

varying float alpha;

void vertex() {
	alpha = COLOR.a;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p * vec2(1.0, 0.75));
	float m = smoothstep(1.0, 0.55, r);
	ALBEDO = vec3(0.55, 0.38, 0.28);
	ALPHA = m * alpha * 0.55;
}
