shader_type sky;
// Ciclorama do estúdio (vitrine): fundo escuro com degradê, brilho atrás do carro e "softboxes" (painéis de luz)
// que só aparecem nos reflexos (passada do cubemap), para a pintura e os cromados terem o que refletir.
uniform vec3 top_col : source_color = vec3(0.02, 0.02, 0.04);
uniform vec3 hor_col : source_color = vec3(0.055, 0.05, 0.1);
uniform vec3 floor_col : source_color = vec3(0.055, 0.05, 0.1);
uniform vec3 accent : source_color = vec3(1.0, 0.7, 0.1);
uniform float glow = 0.35;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	// degradê simétrico em volta do horizonte: sem "linha" entre o chão (que some ao longe) e o fundo
	vec3 c = mix(hor_col, top_col, smoothstep(0.0, 0.55, abs(h)));
	c = mix(c, floor_col, step(h, 0.0) * 0.0);
	// brilho quente atrás do carro (a câmera olha para -Z)
	float back = max(dot(d, normalize(vec3(0.0, 0.12, -1.0))), 0.0);
	c += accent * pow(back, 10.0) * glow * 0.35 + hor_col * pow(back, 3.0) * 0.6;
	if (AT_CUBEMAP_PASS) {
		// softboxes: faixa de luz no teto e dois painéis laterais
		float az = atan(d.x, d.z);
		float top = smoothstep(0.62, 0.68, h) * smoothstep(0.98, 0.9, h) * smoothstep(0.55, 0.4, abs(d.x));
		float side = smoothstep(0.05, 0.12, h) * smoothstep(0.45, 0.36, h) * smoothstep(0.32, 0.22, abs(abs(az) - 1.2));
		c += vec3(1.0) * top * 2.4 + vec3(0.9, 0.95, 1.0) * side * 1.2;
	}
	COLOR = c;
}
