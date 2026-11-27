// Anel de chão do jogador: aro na cor dele com borda de tinta e um medalhão com o símbolo (torre, sino, barril,
// raio) na frente. A forma separa os jogadores mesmo quando a cor falha (daltonismo: vermelhão x ouro).
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
uniform vec3 cor : source_color = vec3(0.850, 0.280, 0.170);
uniform int simbolo = 0;
const vec3 TINTA = vec3(0.0168, 0.0116, 0.0085);
const vec3 PAPEL = vec3(0.8154, 0.7388, 0.5837);
void vertex() {
	float d = dot(VERTEX.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
}
float caixa(vec2 p, vec2 c, vec2 h) { vec2 d = abs(p - c) - h; return step(max(d.x, d.y), 0.0); }
float sim(vec2 p, int s) {
	// p em -1..1 dentro do medalhão
	if (s == 0) { // torre com ameias
		float t = caixa(p, vec2(0.0, 0.15), vec2(0.38, 0.5));
		t = max(t, caixa(p, vec2(-0.28, -0.42), vec2(0.1, 0.12)));
		t = max(t, caixa(p, vec2(0.0, -0.42), vec2(0.1, 0.12)));
		t = max(t, caixa(p, vec2(0.28, -0.42), vec2(0.1, 0.12)));
		return t * (1.0 - caixa(p, vec2(0.0, 0.42), vec2(0.12, 0.22)));
	} else if (s == 1) { // sino
		float w = mix(0.22, 0.55, smoothstep(-0.5, 0.45, p.y));
		float b = step(abs(p.x), w) * step(-0.55, p.y) * step(p.y, 0.45);
		b = max(b, step(length(p - vec2(0.0, -0.5)), 0.24));
		return max(b, step(length(p - vec2(0.0, 0.58)), 0.12));
	} else if (s == 2) { // barril com aros
		float b = step(pow(abs(p.x) / 0.5, 2.0) + pow(abs(p.y) / 0.65, 4.0), 1.0);
		return b * (1.0 - step(abs(abs(p.y) - 0.3), 0.06));
	}
	// raio em zigue-zague
	vec2 q = p;
	float a = step(abs(q.x + q.y * 0.45 - 0.12), 0.16) * step(-0.75, q.y) * step(q.y, 0.0);
	float b = step(abs(q.x + q.y * 0.45 + 0.08), 0.16) * step(0.0, q.y) * step(q.y, 0.75);
	return max(max(a, b), caixa(q, vec2(0.0, 0.0), vec2(0.3, 0.08)));
}
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c);
	vec3 col = vec3(0.0);
	float a = 0.0;
	// aro
	if (r > 0.38 && r < 0.47) { a = 1.0; col = (r < 0.395 || r > 0.455) ? TINTA : cor; }
	// medalhão na frente (para a câmera)
	vec2 m = (UV - vec2(0.5, 0.86)) / 0.13;
	float rm = length(m);
	if (rm < 1.0) { a = 1.0; col = rm > 0.86 ? TINTA : cor; if (sim(m * 1.25, simbolo) > 0.5 && rm < 0.86) col = PAPEL; }
	if (a < 0.5) discard;
	ALBEDO = col;
}
