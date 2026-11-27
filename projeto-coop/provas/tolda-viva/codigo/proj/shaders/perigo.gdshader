// Telegrafia inimiga (v2): vermelhão SEMPRE, mas desenhado como costura de marcação de palco
// (ponto-atrás tracejado, cada ponto inclinado como linha de verdade) e um preenchimento que avança
// de fora para dentro durante a preparação, para dar o tempo. Sem preto, sem zebra de obra.
// 'fecha' vai de 0 a 1 até o golpe. modo 0 = anel (contrapeso, pisada), 1 = retângulo (bastidor),
// 2 = faixa (avanço: o preenchimento corre da praga para a ponta).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 verm : source_color = vec3(0.886, 0.251, 0.106);
uniform vec3 verm_esc : source_color = vec3(0.55, 0.13, 0.07);
uniform int modo = 0;
uniform float fecha = 0.0;
uniform float alpha = 0.95;
uniform float sentido = 1.0;
uniform vec2 tam = vec2(1.0, 1.0);   // tamanho do decalque em metros (pontos com passo constante)
float costura(float s, float d, float passo, float larg) {
	// s: comprimento ao longo da borda (m); d: distância assinada até a linha da borda (m)
	float f = fract(s / passo);
	float on = step(f, 0.64);
	float tilt = (f - 0.32) * larg * 1.3;  // ponto inclinado
	return on * step(abs(d - tilt), larg);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 pm = p * tam * 0.5;  // em metros, centro 0
	float stitch = 0.0; float fill = 0.0; float front = 0.0;
	if (modo == 0) {
		float R = 0.92 * tam.x * 0.5;
		float r = length(pm);
		float ang = atan(pm.y, pm.x);
		stitch = costura(ang * R, r - R, 0.11, 0.022);
		float rin = mix(R, 0.0, fecha);
		fill = step(rin, r) * step(r, R - 0.03);
		front = step(abs(r - rin), 0.018) * step(0.02, fecha) * step(r, R - 0.03);
	} else {
		vec2 hs = vec2(0.92) * tam * 0.5;
		vec2 a = abs(pm);
		vec2 dd = a - hs;
		float d = max(dd.x, dd.y);
		float s = (dd.x > dd.y) ? pm.y * sign(pm.x) : pm.x * sign(pm.y) + 7.0;
		stitch = costura(s, d, 0.11, 0.022);
		if (modo == 1) {
			float k = 1.0 - fecha;
			fill = step(d, -0.03) * step(-min(hs.x, hs.y) * k - 0.0001, d) ;
			front = step(abs(d + min(hs.x, hs.y) * k), 0.016) * step(0.02, fecha) * step(d, -0.03);
		} else {
			float x = p.x * sentido;  // -1 = na praga, 1 = ponta
			float lim = mix(-1.0, 1.0, fecha);
			fill = step(x, lim) * step(d, -0.03);
			front = step(abs(x - lim), 0.02) * step(d, -0.03);
			// divisas internas apontando o sentido do bote (forma, não só cor)
			float chev = fract((x * tam.x * 0.5 - abs(pm.y) * 0.9) / 0.38);
			fill = max(fill, step(chev, 0.12) * step(d, -0.06) * 0.55);
		}
	}
	float a = max(stitch, max(front, fill * 0.26));
	if (a < 0.01) discard;
	vec3 c = verm;
	c = mix(c, verm_esc, (1.0 - stitch) * (1.0 - front) * 0.25);
	ALBEDO = c;
	ALPHA = alpha * a;
}
