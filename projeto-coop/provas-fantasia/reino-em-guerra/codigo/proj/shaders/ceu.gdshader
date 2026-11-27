// Céu de tempestade em água-forte: faixas horizontais de aquatinta, nuvens gravadas em hachura cruzada que rolam do
// oeste (esquerda), um rasgo de papel âmbar a leste onde o sol se põe. Funciona igual no Compatibility.
shader_type sky;
uniform vec3 papel_frio : source_color = vec3(0.557, 0.592, 0.639);
uniform vec3 papel_quente : source_color = vec3(0.890, 0.788, 0.604);
uniform vec3 papel_dia : source_color = vec3(0.914, 0.875, 0.788);
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform float tempo = 0.0;
uniform float clarao = 0.0;
uniform vec2 conv = vec2(0.0, 0.0);   // direção (az, el) para onde as linhas convergem (raio chegando)
uniform float conv_k = 0.0;
uniform float yaw0 = 0.0;
uniform float baixo = 1.0;    // low key: céu de tempestade quase preto no alto
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 1.7) * 0.28 + vn(p * 4.1 + 3.3) * 0.14 + vn(p * 8.3) * 0.08; }
float linhas(vec2 q, float ang, float esp, float w) {
	vec2 d = vec2(cos(ang), sin(ang));
	float s = dot(q, d) / esp;
	if (w <= 0.01) return 0.0;
	return 1.0 - smoothstep(w * 0.5 - 0.06, w * 0.5 + 0.06, abs(fract(s) - 0.5));
}
void sky() {
	vec3 d = EYEDIR;
	float az = atan(d.x, -d.z) - yaw0;    // 0 = norte
	float el = asin(clamp(d.y, -1.0, 1.0));
	vec2 q = vec2(az * 60.0, el * 60.0);  // "graus"
	float tq = floor(tempo * 12.0) / 12.0;
	// nuvens rolando do oeste
	float n = fbm(vec2(q.x * 0.045 - tq * 0.18, q.y * 0.12));
	float tempestade = smoothstep(25.0, -40.0, q.x);           // mais escuro à esquerda
	float dens = clamp(n * 1.4 - 0.55 + tempestade * 0.55 + smoothstep(3.0, 18.0, q.y) * 0.55 + baixo * 0.3, 0.0, 1.0);
	// rasgo âmbar a leste, perto do horizonte
	float rasgo = smoothstep(4.0, 30.0, q.x) * smoothstep(7.0, 1.0, abs(q.y - 2.0 - 1.5 * sin(q.x * 0.08))) * (1.0 - smoothstep(0.55, 0.85, n));
	vec3 papel = h21(floor(SCREEN_UV * vec2(1920.0, 1080.0))) < smoothstep(-8.0, 30.0, q.x) ? papel_quente : papel_frio;
	vec3 c = papel;
	// camadas de linha conforme a densidade (linhas horizontais de aquatinta e hachura cruzada nas nuvens)
	vec2 sp = SCREEN_UV * vec2(1920.0, 1080.0);
	float L1 = linhas(sp, 1.6, 4.0, 0.45 * smoothstep(0.3, 0.75, dens));
	float L2 = linhas(sp + vec2(n * 9.0), 0.75, 4.5, 0.4 * smoothstep(0.55, 0.9, dens));
	float L3 = linhas(sp, 2.3, 5.0, 0.35 * smoothstep(0.8, 1.0, dens));
	// alto do céu: a quarta família e o grão de resina fecham quase em preto (low key)
	float L4 = linhas(sp + vec2(3.0, 1.0), 0.2, 3.6, 0.62 * smoothstep(8.0, 26.0, q.y) * baixo);
	float L5 = linhas(sp, 1.15, 4.2, 0.5 * smoothstep(14.0, 34.0, q.y) * baixo);
	// borda da nuvem: um traço contínuo onde a densidade cruza 0,35
	float borda_n = 1.0 - smoothstep(0.0, 0.03, abs(dens - 0.35));
	// convergência para o mastro: linhas radiais de papel cortando a nuvem
	if (conv_k > 0.0) {
		vec2 cq = q - conv * 60.0;
		float ang = atan(cq.y, cq.x);
		float ray = abs(fract(ang * 18.0 / 6.2832) - 0.5);
		float rad = (1.0 - smoothstep(0.0, 0.06, ray)) * smoothstep(60.0, 5.0, length(cq));
		L1 = max(L1, rad * conv_k);
		L2 *= 1.0 - conv_k * 0.6;
	}
	float ink = 1.0 - (1.0 - L1) * (1.0 - L2) * (1.0 - L3) * (1.0 - L4) * (1.0 - L5);
	ink = min(ink, 0.93);
	c = mix(c, tinta, ink);
	c = mix(c, papel_dia, rasgo);
	// grão de aquatinta perto do horizonte
	float hg = smoothstep(8.0, 0.0, q.y) * 0.35;
	float g = h21(floor(sp) + floor(tempo * 2.0) * 0.0);
	c = mix(c, mix(papel_frio, papel_quente, smoothstep(-10.0, 30.0, q.x)), step(g, hg * 1.6 * (1.0 - rasgo)));
	c = mix(c, papel_dia * 1.3, clarao);
	COLOR = c;
}
