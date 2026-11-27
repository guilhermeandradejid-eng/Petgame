// Anel no chão: marcador de jogador (anel + símbolo: 0 quadrado, 1 triângulo, 2 círculo, 3 losango),
// anel de pegada (recortado, abre em degrau) e anel da Tralha Grande. Tinta chapada com borda de tinta.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
uniform vec3 cor : source_color = vec3(0.85, 0.27, 0.17);
uniform vec3 tinta : source_color = vec3(0.118, 0.102, 0.133);
uniform int modo = 0;          // 0 marcador, 1 pegada, 2 alvo (Tralha Grande)
uniform int simbolo = 0;
uniform float raio = 0.9;      // em unidades do quad (0..1 = borda)
uniform float esp = 0.12;
uniform float alfa = 1.0;
uniform float cortes = 6.0;
float sdbox(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float sym(vec2 p, int s) {
	if (s == 0) return sdbox(p, vec2(0.11));
	if (s == 1) { vec2 q = p - vec2(0.0, -0.03); return max(-q.y - 0.09, max(abs(q.x) * 0.866 + q.y * 0.5 - 0.06, 0.0) ); }
	if (s == 2) return length(p) - 0.12;
	return abs(p.x) + abs(p.y) - 0.15;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 c = cor;
	float m = 0.0;
	if (modo == 0) {
		// anel com abertura na frente, onde fica o símbolo
		float ring = step(abs(r - raio), esp);
		float gap = step(abs(a - 1.5708), 0.34);
		float ink = step(abs(r - raio), esp + 0.035);
		vec2 sp = p - vec2(0.0, raio);
		float sd = sym(sp, simbolo);
		float s_in = step(sd, 0.0);
		float s_ink = step(sd, 0.04);
		m = max(ring * (1.0 - gap), s_in);
		float mi = max(ink * (1.0 - gap), s_ink);
		if (mi < 0.5) discard;
		c = mix(tinta, cor, m);
	} else if (modo == 1) {
		float teeth = 0.5 + 0.5 * cos(a * cortes);
		float ring = step(abs(r - raio), esp * (0.55 + 0.45 * teeth));
		if (ring < 0.5) discard;
		c = cor;
	} else {
		float ring = step(abs(r - raio), esp) * step(0.5, fract(a / 6.2832 * 12.0));
		float dot_ = step(r, 0.18);
		if (max(ring, dot_) < 0.5) discard;
		c = mix(cor, tinta, dot_ * 0.0);
	}
	if (alfa < 0.999) {
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > alfa) discard;
	}
	ALBEDO = c;
}
