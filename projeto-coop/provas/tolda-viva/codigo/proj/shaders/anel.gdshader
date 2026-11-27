// Anel de jogador e símbolo de chão (quadrado, triângulo, círculo, losango) na cor do jogador.
// v2: anel fino (40% da espessura anterior), translúcido, sem seta; o símbolo ficou pequeno e
// assentado no próprio anel, do lado da câmera, como um tique. A forma garante a leitura em daltonismo.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.9, 0.2, 0.5);
uniform int simbolo = 0;  // 0 quadrado, 1 triângulo, 2 círculo, 3 losango
uniform vec3 tinta : source_color = vec3(0.114, 0.094, 0.125);
uniform float alpha = 0.68;
float sd_shape(vec2 p, int s) {
	if (s == 0) { vec2 d = abs(p) - vec2(0.17); return max(d.x, d.y); }
	if (s == 1) { p.y = -p.y + 0.05; float k = sqrt(3.0); p.x = abs(p.x) - 0.2; p.y = p.y + 0.2 / k; if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0; p.x -= clamp(p.x, -0.4, 0.0); return -length(p) * sign(p.y); }
	if (s == 2) { return length(p) - 0.19; }
	return (abs(p.x) + abs(p.y)) / 1.2 - 0.2;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// anel aberto em 4 arcos, fino
	float gap = step(0.2, abs(sin(ang * 2.0 + 0.785)));
	float ring = step(abs(r - 0.84), 0.03) * gap;
	float ringo = step(abs(r - 0.84), 0.048) * step(0.15, abs(sin(ang * 2.0 + 0.785)));
	// símbolo pequeno em cima do anel, do lado da câmera
	vec2 q = (p - vec2(0.0, 0.84)) / 0.52;
	float d = sd_shape(q, simbolo);
	float sym = step(d, 0.0);
	float symo = step(d, 0.07);
	float m = max(ringo, symo);
	if (m < 0.5) discard;
	vec3 c = mix(tinta, cor, max(ring, sym));
	ALBEDO = c;
	ALPHA = max(ring, sym) > 0.5 ? (sym > 0.5 ? 0.92 : alpha) : alpha * 0.8;
}
