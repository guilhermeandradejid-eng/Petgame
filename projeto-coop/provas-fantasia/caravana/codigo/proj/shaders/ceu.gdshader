// Céu em três camadas (laranja-queimado no horizonte, violeta-fuligem no alto), nuvens em faixas pintadas.
// A câmera de combate olha 52° para baixo: o horizonte do mundo dobrado fica em 'horiz' (seno da elevação).
shader_type sky;
uniform float horiz = -0.66;     // seno da elevação do horizonte (visto pela câmera)
uniform float topo = -0.6;       // seno da elevação da borda de cima do quadro
uniform vec3 c_horiz : source_color = vec3(0.86, 0.45, 0.22);
uniform vec3 c_meio : source_color = vec3(0.55, 0.28, 0.3);
uniform vec3 c_alto : source_color = vec3(0.24, 0.2, 0.32);
uniform float ferve_s = 0.0;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y); }
void sky() {
	float e = (EYEDIR.y - horiz) / (topo - horiz);   // 0 no horizonte, 1 na borda de cima
	float az = atan(EYEDIR.x, -EYEDIR.z);
	float ex = e;
	vec3 c = mix(c_horiz * 1.1, c_meio, smoothstep(0.3, 0.75, ex));
	c = mix(c, c_alto, smoothstep(0.8, 1.5, ex));
	// nuvens em faixas: pinceladas longas, borda dura, mais escuras por baixo
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float y0 = 0.25 + fi * 0.32;
		float n = vn(vec2(az * (5.0 + fi * 2.0) + fi * 13.0 + TIME * 0.004 * (fi + 1.0), fi * 7.0)) * 0.7 + vn(vec2(az * 17.0 + fi * 3.0, ex * 4.0)) * 0.3;
		float band = 1.0 - smoothstep(0.0, 0.09 + n * 0.08, abs(ex - y0 - (n - 0.5) * 0.18));
		band = step(0.45, band * (0.4 + n));
		vec3 nc = mix(c * vec3(0.62, 0.52, 0.66), c * vec3(1.12, 0.98, 0.9), step(ex, y0 + (n - 0.5) * 0.18 - 0.02));
		c = mix(c, nc, band * 0.85);
	}
	// sol velho abafado: disco pardo, quase apagado, atrás das nuvens
	vec2 sp = vec2(az - 0.65, ex - 0.32);
	float sd = length(sp * vec2(1.0, 1.6));
	c = mix(c, vec3(1.0, 0.72, 0.42), (1.0 - smoothstep(0.05, 0.065, sd)) * 0.55);
	c += vec3(0.25, 0.1, 0.02) * exp(-sd * 9.0) * 0.6;
	if (ex < 0.0) c = mix(c_horiz, vec3(0.06, 0.07, 0.12), smoothstep(0.0, -0.6, ex));
	COLOR = c;
}
