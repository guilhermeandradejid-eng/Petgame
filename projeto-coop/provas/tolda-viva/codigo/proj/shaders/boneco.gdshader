// Boneco: madeira pintada (cor de vértice) ou pano (tecido × cor de vértice), toon de 2 degraus por light().
// Sombra = multiplicar por uma tinta (nunca preto). Extras: luz das luas pintada (disco no chão também
// "acende" o boneco), clarão de impacto, demão de Tinta (pincelada por máscara) e virar Machê.
shader_type spatial;
render_mode cull_back;
uniform sampler2D tecido : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform vec3 shadow_tint : source_color = vec3(0.50, 0.46, 0.66);
uniform float band = 0.0;
uniform float soft = 0.02;
uniform float flash = 0.0;          // clarão de impacto (0..1), 85% de valor no máximo
uniform float tinta = 0.0;          // demãos de Tinta (0..3)
uniform vec3 tinta_col : source_color = vec3(0.208, 0.314, 0.847);
uniform float mache = 0.0;          // 0..1: vira papel machê
uniform float rachado = 0.0;        // rachaduras do machê
uniform vec3 mache_col : source_color = vec3(0.92, 0.86, 0.72);
uniform vec4 luas[4];               // xyz = centro do disco no chão, w = raio
uniform vec3 lua_col : source_color = vec3(1.0, 0.86, 0.55);
uniform float lua_amt = 0.22;
uniform float rim_amt = 0.0;        // contraluz fria (v2: ligada nos carunchos de laca)
uniform float laca = 0.0;           // v2: brilho duro de laca (banda de especular em degrau)
uniform float veio = 0.0;           // v2: veio de madeira em baixa frequência (só na madeira lisa)
uniform vec3 rim_col : source_color = vec3(0.65, 0.75, 1.0);
varying vec3 wpos;
varying vec3 opos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = VERTEX;
}
vec3 srgb_fix(vec3 vc) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vc = mix(vc * 12.92, 1.055 * pow(vc, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), vc));
#endif
	return vc;
}
void fragment() {
	vec3 vc = srgb_fix(COLOR.rgb);
	vec3 c = use_tex ? texture(tecido, UV).rgb * vc : vc;
	if (veio > 0.0 && !use_tex) {
		float g = vn(vec2(opos.x * 5.0 + opos.y * 5.0, opos.z * 34.0 + 4.0 * vn(opos.xy * 3.0)));
		c *= 1.0 + veio * (g - 0.5) * 2.0;
	}
	// demão de Tinta: pinceladas largas com cerdas, em espaço do objeto
	if (tinta > 0.0) {
		float stroke = 0.0;
		for (int k = 0; k < 3; k++) {
			if (float(k) < tinta) {
				float fk = float(k);
				vec2 q = vec2(opos.x * cos(fk * 1.7) + opos.y * sin(fk * 1.7), opos.z + 0.08 * fk);
				float h = abs(q.y - 0.3 - 0.12 * sin(q.x * 6.0 + fk * 2.0)) - (0.07 + 0.02 * fk);
				float bristle = vn(vec2(q.x * 2.0, q.y * 90.0));
				stroke = max(stroke, step(h, 0.0) * step(0.25, bristle + 0.4 + h * 4.0));
			}
		}
		c = mix(c, tinta_col * (0.85 + 0.2 * vn(opos.xz * 40.0)), stroke);
	}
	// papel machê: tiras de papel coladas, cor creme, rachaduras escuras
	if (mache > 0.0) {
		vec2 sp = vec2(dot(opos, vec3(0.8, 0.3, 0.5)), dot(opos, vec3(-0.3, 0.9, 0.2)));
		float strip = vn(sp * vec2(4.0, 26.0));
		vec3 pc = mache_col * (0.86 + 0.18 * strip);
		float grow = smoothstep(mache * 1.6 - 0.4, mache * 1.6, 1.0 - (opos.z + 0.2));
		c = mix(c, pc, clamp(mache * 1.4, 0.0, 1.0));
		float cr = abs(vn(opos.xz * 9.0 + opos.y * 3.0) - 0.5);
		c = mix(c, vec3(0.08, 0.06, 0.07), rachado * step(cr, 0.035 * rachado));
	}
	ALBEDO = c;
	// disco de luz das luas: aquece o boneco dentro do disco pintado no chão
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		if (luas[i].w > 0.0) {
			float d = length(wpos.xz - luas[i].xz) / luas[i].w;
			lit = max(lit, smoothstep(1.0, 0.75, d));
		}
	}
	EMISSION = c * lua_col * lit * lua_amt + vec3(0.85) * flash;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k = smoothstep(band - soft, band + soft, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		// luz-chave: sombra própria = multiplicar por uma tinta, nunca preto
		k *= ATTENUATION;
		DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), k) * LIGHT_COLOR / PI;
	} else {
		// v2: canhão de palco (spot): só soma dentro do cone, com a mesma regra de 2 degraus
		DIFFUSE_LIGHT += mix(shadow_tint * 0.6, vec3(1.0), k) * ATTENUATION * LIGHT_COLOR / PI;
	}
	if (laca > 0.0) {
		vec3 H = normalize(LIGHT + VIEW);
		float s = smoothstep(0.972, 0.976, dot(NORMAL, H)) * min(1.0, ATTENUATION * 4.0);
		s *= step(0.08, ALBEDO.r) * step(ALBEDO.g, 0.12);  // só no casco vermelho (não nas pernas finas)
		SPECULAR_LIGHT += s * laca * LIGHT_COLOR;
	}
	if (rim_amt > 0.0 && LIGHT_IS_DIRECTIONAL) {
		float rim = smoothstep(0.58, 0.62, 1.0 - dot(NORMAL, VIEW));
		DIFFUSE_LIGHT += rim * rim_amt * rim_col * LIGHT_COLOR / PI;
	}
}
