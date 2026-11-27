// Praticável: tábuas (textura gerada) com toon por light() e sombra só por tinta; discos de luz das
// luas pintados (borda de pincel), escurecendo para a coxia. Recebe sombra real só no nível PC.
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tabuas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 tamanho = vec2(20.0, 14.0);
uniform vec4 luas[4];
uniform vec3 lua_col : source_color = vec3(1.2, 1.12, 0.98);
uniform float lua_amt = 0.42;
uniform vec3 noite : source_color = vec3(1.0, 0.98, 0.97);
uniform vec3 shadow_tint : source_color = vec3(0.50, 0.46, 0.66);
uniform vec4 foco = vec4(0.0, 0.0, 0.0, 0.0); // xz centro, z raio, w força (canhão seguidor de teatro)
uniform vec3 coxia_col : source_color = vec3(0.16, 0.14, 0.24);
uniform vec3 pinho = vec3(0.456, 0.33, 0.2);  // linear (sem source_color: igual nos dois renderers)
uniform float l_media = 0.25;
uniform float contraste = 0.42;
varying vec3 wpos;
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz / tamanho + 0.5;
	vec3 c = texture(tabuas, uv).rgb;
	// v2: pinho claro e pouco saturado; a textura só dá o detalhe (veio, frestas, pregos), com o
	// contraste comprimido a ±5% no valor (o chão é a camada calma entre heróis e inimigos)
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = pinho * (1.0 + (l / l_media - 1.0) * contraste);
	// disco de luz pintado: borda irregular de pincel e leve degrau (2 tons), nunca degradê liso
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		if (luas[i].w > 0.0) {
			vec2 d = wpos.xz - luas[i].xz;
			float a = atan(d.y, d.x);
			float r = length(d) / luas[i].w;
			float edge = 1.0 + 0.05 * (vn(vec2(a * 4.0, float(i) * 7.0)) - 0.5) + 0.015 * (vn(vec2(a * 17.0, float(i))) - 0.5);
			float brush = vn(wpos.xz * vec2(3.0, 40.0)) * 0.03;
			lit = max(lit, smoothstep(edge, edge - 0.04, r + brush) * 0.6 + smoothstep(edge * 0.62, edge * 0.58, r + brush) * 0.4);
		}
	}
	c = c * mix(noite, lua_col * 1.08, lit);
	// coxia: escurece para os lados e para o fundo
	float side = smoothstep(6.5, 10.0, abs(wpos.x)) + smoothstep(-4.5, -7.5, wpos.z) * 0.7;
	c = mix(c, c * coxia_col * 2.0, clamp(side, 0.0, 1.0));
	if (foco.w > 0.0) {
		float fd = length(wpos.xz - foco.xy) / foco.z;
		float fa = atan(wpos.z - foco.y, wpos.x - foco.x);
		fd += 0.03 * sin(fa * 7.0) + 0.02 * sin(fa * 13.0);
		c *= mix(1.0, 1.0 - foco.w, smoothstep(0.92, 1.0, fd) * 0.5 + smoothstep(1.05, 1.5, fd) * 0.5);
	}
	ALBEDO = c;
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float k = smoothstep(-0.02, 0.02, dot(NORMAL, LIGHT)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), k) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI;
	}
}
