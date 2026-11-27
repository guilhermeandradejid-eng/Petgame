// Impacto de "caco": quadro 0 = lampejo branco com contorno de tinta; quadros 1 a 3 = rachadura em
// linha de tinta que se abre a partir do ponto de golpe, com a matéria acesa dentro da fenda
// (Faísca amarela, Brasa laranja, Cal branca). Some por limiar de ruído (não por alfa).
// ground = 1: decalque deitado no chão (o próprio azulejo racha); 0: billboard sobre o alvo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform float life = 0.0;          // 0..1
uniform float ground = 0.0;
uniform float seed = 0.0;
uniform float rays = 6.0;
uniform vec3 glow : source_color = vec3(0.953, 0.776, 0.192);
uniform vec3 ink : source_color = vec3(0.051, 0.063, 0.161);
uniform vec3 flash_col : source_color = vec3(1.0, 0.99, 0.95);
uniform float emit = 2.2;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	if (ground < 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}
// distância a uma fenda angulosa (3 segmentos retos com quebras secas) e a um galho lateral
float ray_d(vec2 p, float a, float L, float k) {
	float best = 9.0;
	vec2 q0 = vec2(0.06 * cos(a), 0.06 * sin(a));
	float ang = a;
	vec2 mid = q0;
	for (int i = 1; i <= 3; i++) {
		ang += (hash(vec2(k, float(i) + seed)) - 0.5) * 1.1;
		vec2 q1 = q0 + vec2(cos(ang), sin(ang)) * L * (i == 1 ? 0.4 : 0.3);
		vec2 pa = p - q0, ba = q1 - q0;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		best = min(best, length(pa - ba * h) * (1.0 + 0.6 * (float(i) - 1.0 + h)));
		if (i == 1) mid = q1;
		q0 = q1;
	}
	// galho
	float ba2 = a + (hash(vec2(k, seed + 9.0)) > 0.5 ? 0.9 : -0.9);
	vec2 b1 = mid + vec2(cos(ba2), sin(ba2)) * L * 0.25;
	vec2 pa = p - mid, bb = b1 - mid;
	float h = clamp(dot(pa, bb) / dot(bb, bb), 0.0, 1.0);
	best = min(best, length(pa - bb * h) * (1.6 + h));
	return best;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = vn(UV * 22.0 + seed * 3.0);
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (life < 0.12) {
		// lampejo: estouro branco irregular com borda de tinta (1 quadro)
		float ang = atan(p.y, p.x);
		float R = 0.55 + 0.2 * vn(vec2(ang * 2.5 + seed, seed));
		float body = step(r, R);
		float rim = step(r, R + 0.06);
		c = mix(ink, flash_col, body);
		a = rim;
		EMISSION = flash_col * body * 1.5;
	} else {
		float open = smoothstep(0.12, 0.45, life);          // a rachadura se abre nos quadros 1 a 3
		float L = mix(0.35, 0.95, open);
		float d = 9.0;
		for (int k = 0; k < 8; k++) {
			if (float(k) >= rays) break;
			float ak = 6.2831 * (float(k) + hash(vec2(float(k), seed)) * 0.6) / rays + seed;
			d = min(d, ray_d(p, ak, L * (0.65 + 0.35 * hash(vec2(seed, float(k)))), float(k)));
		}
		float w = mix(0.012, 0.02, open);
		float line = 1.0 - smoothstep(w * 1.55, w * 1.55 + 0.01, d);     // borda de tinta fina
		float core = 1.0 - smoothstep(w * 0.8, w * 0.8 + 0.008, d);       // fenda acesa (domina)
		c = mix(ink, glow, core);
		a = line;
		EMISSION = glow * core * emit * (1.0 - smoothstep(0.5, 1.0, life));
		// dissolve por limiar de ruído
		if (n < smoothstep(0.55, 1.0, life) * 1.05) a = 0.0;
	}
	if (a < 0.5) discard;
	ALBEDO = c;
}
