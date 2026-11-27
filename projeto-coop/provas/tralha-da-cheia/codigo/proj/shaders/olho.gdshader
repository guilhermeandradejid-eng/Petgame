// Olho de ponto pintado (heróis) ou olho único brilhante (Inchados). Quad com UV 0..1, sem textura.
// abertura: 1 aberto, 0 fechado (vira um arco de tinta), olhar: desvio da pupila.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform int tipo = 0;              // 0 = ponto de herói; 1 = olho de Inchado
uniform float abertura = 1.0;
uniform vec2 olhar = vec2(0.0);
uniform float raiva = 0.0;         // pálpebra inclinada (telegrafia)
uniform vec3 tinta : source_color = vec3(0.118, 0.102, 0.133);
uniform vec3 creme : source_color = vec3(0.93, 0.88, 0.78);
uniform vec3 iris : source_color = vec3(1.0, 0.31, 0.64);
uniform float brilho = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (tipo == 0) {
		if (abertura > 0.3) {
			// olho de boneco pintado: branco de creme com borda de tinta, pupila grande e brilho (lê sobre pele escura)
			float d0 = length(p * vec2(1.0, 0.86));
			if (d0 > 0.96) discard;
			float d = length((p - olhar * 0.25 - vec2(0.0, -0.06)) * vec2(1.0, 0.86));
			vec3 c = creme;
			c = mix(c, tinta, step(d, 0.56));
			c = mix(c, creme, step(length(p - olhar * 0.25 - vec2(-0.16, 0.12)), 0.17));
			c = mix(c, tinta, step(0.82, d0));
			ALBEDO = c;
		} else {
			// fechado: arco "^" de tinta
			float y = 0.25 - 0.55 * p.x * p.x;
			if (abs(p.y - y) > 0.16 || abs(p.x) > 0.75) discard;
			ALBEDO = tinta;
		}
	} else {
		float d = length(p);
		if (d > 0.98) discard;
		float lid = mix(1.2, -1.0, 1.0 - abertura) - raiva * 0.5 * (p.x + 1.0) * 0.5;
		vec3 c = creme;
		vec2 q = p - olhar * 0.35;
		c = mix(c, iris * brilho, step(length(q), 0.5));
		c = mix(c, tinta, step(length(q), 0.22));
		c = mix(c, creme, step(length(q - vec2(-0.14, 0.16)), 0.1));
		c = mix(c, tinta, step(0.86, d));
		c = mix(c, vec3(0.38, 0.34, 0.31), step(lid, p.y));
		c = mix(c, tinta, step(abs(p.y - lid), 0.08) * step(d, 0.95));
		ALBEDO = c;
	}
}
