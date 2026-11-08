shader_type spatial;
render_mode cull_disabled;
// Chão do tema: 0 grama, 1 areia (dunas), 2 neve, 3 água, 4 lava, 5 lua (crateras), 6 cidade, 7 tapete xadrez, 8 nuvens.
uniform int mode = 0;
uniform vec4 col_a : source_color = vec4(0.3, 0.6, 0.2, 1.0);
uniform vec4 col_b : source_color = vec4(0.4, 0.7, 0.3, 1.0);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.1) * 0.27 + noise(p * 4.3) * 0.15 + noise(p * 8.7) * 0.08; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 q = wpos.xz;
	float n = fbm(q * 0.05);
	vec3 c = mix(col_a.rgb, col_b.rgb, n);
	float rough = 1.0;
	float spec = 0.2;
	vec3 emit = vec3(0.0);
	if (mode == 0) {
		c = mix(col_a.rgb, col_b.rgb, fbm(q * 0.06) * 0.7 + hash(floor(q * 3.0)) * 0.3);
	} else if (mode == 1) {
		float dune = sin(q.x * 0.05 + fbm(q * 0.02) * 6.0) * 0.5 + 0.5;
		c = mix(col_a.rgb, col_b.rgb, dune * 0.6 + n * 0.4);
	} else if (mode == 2) {
		c = mix(col_a.rgb, col_b.rgb, n) ;
		spec = 0.5;
		rough = 0.6;
	} else if (mode == 3) {
		float w = fbm(q * 0.08 + vec2(TIME * 0.12, TIME * 0.07)) + fbm(q * 0.15 - vec2(TIME * 0.1, 0.0)) * 0.5;
		c = mix(col_a.rgb, col_b.rgb, w * 0.8);
		c += vec3(0.6, 0.8, 1.0) * smoothstep(0.82, 0.95, w) * 0.4;
		rough = 0.15;
		spec = 0.7;
	} else if (mode == 4) {
		float crack = fbm(q * 0.06 + vec2(TIME * 0.03, 0.0));
		float lava = smoothstep(0.45, 0.62, crack);
		c = mix(col_a.rgb * (0.7 + n * 0.5), col_b.rgb, lava);
		emit = col_b.rgb * lava * (0.8 + sin(TIME * 2.0 + q.x * 0.1) * 0.25);
	} else if (mode == 5) {
		float cr = 0.0;
		for (int k = 0; k < 3; k++) {
			vec2 g = q * (0.03 * float(k + 1));
			vec2 cell = floor(g);
			vec2 f = fract(g) - 0.5 - (vec2(hash(cell), hash(cell + 3.1)) - 0.5) * 0.4;
			float r = length(f);
			float rad = 0.2 + hash(cell + 7.0) * 0.2;
			cr += smoothstep(rad, rad - 0.04, r) * 0.35 - smoothstep(rad + 0.05, rad, r) * smoothstep(rad - 0.04, rad, r) * 0.6;
		}
		c = mix(col_a.rgb, col_b.rgb, n) * (1.0 - cr);
	} else if (mode == 6) {
		vec2 g = fract(q / 12.0);
		float line = step(g.x, 0.02) + step(g.y, 0.02);
		c = mix(col_a.rgb, col_b.rgb, n) * (1.0 - 0.3 * clamp(line, 0.0, 1.0));
		spec = 0.4;
		rough = 0.5;
	} else if (mode == 7) {
		vec2 g = floor(q / 8.0);
		float k = mod(g.x + g.y, 2.0);
		c = mix(col_a.rgb, col_b.rgb, k) * (0.95 + n * 0.08);
	} else if (mode == 8) {
		// mar de nuvens: camadas que andam devagar, topo iluminado pelo sol, vales azulados e frestas
		vec2 wq = q + vec2(TIME * 0.6, TIME * 0.25);
		float big = fbm(wq * 0.008);
		float cl = fbm(wq * 0.018 + big * 1.5);
		float puff = fbm(wq * 0.06 + vec2(3.0, 1.0));
		float h = smoothstep(0.3, 0.75, cl * 0.75 + puff * 0.35);
		vec3 deep = vec3(0.42, 0.55, 0.86);
		vec3 lit = mix(col_a.rgb, vec3(1.0, 0.96, 0.9), 0.4);
		vec3 shade = mix(col_b.rgb, deep, 0.35);
		c = mix(deep, mix(shade, lit, smoothstep(0.45, 0.85, puff + h * 0.4)), h);
		// sombras de nuvens altas passando
		float sh = smoothstep(0.55, 0.75, fbm(q * 0.006 + vec2(TIME * 0.02, 0.0)));
		c *= 1.0 - sh * 0.18;
		emit = c * 0.22;
		rough = 1.0;
		spec = 0.1;
	} else if (mode == 9) {
		// pântano: água escura e parada, lentilha-d'água em manchas, vitórias-régias, ondinhas e reflexo
		float t = TIME * 0.05;
		float murk = fbm(q * 0.04 + vec2(t, 0.0));
		c = mix(col_a.rgb * 0.55, col_b.rgb * 0.62, murk);
		float weed = smoothstep(0.62, 0.74, fbm(q * 0.09 + vec2(4.0, t * 0.5)) + hash(floor(q * 6.0)) * 0.05);
		c = mix(c, vec3(0.36, 0.5, 0.14), weed * 0.85);
		// vitórias-régias: discos verdes com um "corte" em V
		vec2 g = q * 0.22;
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5 - (vec2(hash(cell), hash(cell + 5.3)) - 0.5) * 0.5;
		float rad = 0.12 + hash(cell + 9.1) * 0.1;
		float ang = atan(f.y, f.x) + hash(cell) * 6.28;
		float notch = step(0.25, abs(fract(ang / 6.2831 + 0.5) - 0.5) * 2.0 + 0.0);
		float pad = smoothstep(rad, rad - 0.02, length(f)) * step(0.72, hash(cell + 2.2)) * (1.0 - step(abs(sin(ang * 0.5)), 0.12));
		c = mix(c, vec3(0.3, 0.56, 0.2) * (0.85 + 0.15 * sin(length(f) * 60.0)), pad);
		float rip = sin(length(fract(q * 0.05) - 0.5) * 40.0 - TIME * 2.0) * 0.5 + 0.5;
		c += vec3(0.05, 0.06, 0.04) * rip * (1.0 - weed) * (1.0 - pad) * 0.4;
		rough = mix(0.12, 0.8, max(weed, pad));
		spec = mix(0.75, 0.3, max(weed, pad));
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
