// Faísca em voo: miolo branco-quente com borda de antimônio e de tinta, e 3 arcos curtos em
// zigue-zague que mudam a cada quadro de raio (30 por segundo). Não é estrela.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform float time = 0.0;
uniform vec3 col : source_color = vec3(0.953, 0.776, 0.192);
uniform vec3 core : source_color = vec3(1.0, 0.98, 0.88);
uniform vec3 ink : source_color = vec3(0.051, 0.063, 0.161);
uniform float emit = 2.4;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fr = floor(time * 30.0);
	float r = length(p);
	float d = r - 0.26;
	float arcs = 9.0;
	for (int k = 0; k < 3; k++) {
		float a = 6.2831 * (float(k) / 3.0 + hash(vec2(fr, float(k))) * 0.3);
		vec2 q0 = vec2(cos(a), sin(a)) * 0.22;
		vec2 q1 = vec2(cos(a + 0.5), sin(a + 0.5)) * (0.55 + 0.2 * hash(vec2(float(k), fr + 1.0)));
		vec2 q2 = vec2(cos(a - 0.1), sin(a - 0.1)) * (0.8 + 0.15 * hash(vec2(fr, float(k) + 3.0)));
		arcs = min(arcs, min(seg(p, q0, q1), seg(p, q1, q2)));
	}
	float body = step(d, 0.0);
	float rim = step(d, 0.09);
	float arc = step(arcs, 0.045);
	float arc_e = step(arcs, 0.085);
	float a_ = max(max(rim, arc_e), 0.0);
	if (a_ < 0.5) discard;
	vec3 c = ink;
	c = mix(c, col, max(step(d, 0.05), arc));
	c = mix(c, core, step(r, 0.16));
	ALBEDO = c;
	EMISSION = (c - ink) * emit;
}
