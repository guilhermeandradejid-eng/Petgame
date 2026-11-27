// Reflexo falso do chão molhado de cal (só Forward+): película transparente sobre o piso que faz
// um ray-march curto em espaço de tela (tela + profundidade) na direção refletida e devolve o que
// estiver de pé sobre a poça (personagens, adereços). Mascarada pelo mesmo mapa de molhado do piso.
// No Compatibility a película não desenha nada (o piso só escurece).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D state : filter_linear, repeat_disable;
uniform vec4 state_rect = vec4(-9.0, -6.0, 18.0, 12.0);
uniform float T = 0.25;
uniform float strength = 0.55;
uniform vec3 tint : source_color = vec3(0.80, 0.86, 1.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	discard;
#else
	vec2 p = wpos.xz;
	vec4 st = texture(state, (p - state_rect.xy) / state_rect.zw);
	float nwet = fbm(p * 2.3) * 0.5 + fbm(p * 9.0) * 0.25;
	float wv = st.r + (nwet - 0.4) * 0.35;
	float wet = smoothstep(0.445, 0.46, wv);
	if (wet < 0.01) discard;
	vec3 n = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// ondulação: a normal treme um pouco (reflexo quebrado em faixas, não espelho perfeito)
	n = normalize(n + (VIEW_MATRIX * vec4((vn(p * 7.0) - 0.5) * 0.06, 0.0, (vn(p * 7.0 + 3.0) - 0.5) * 0.03, 0.0)).xyz);
	vec3 v0 = VERTEX;
	vec3 r = reflect(normalize(v0), n);
	vec3 hit_col = vec3(0.0);
	float hit = 0.0;
	float stp = 0.06;
	vec3 pos = v0 + r * 0.03;
	for (int i = 0; i < 40; i++) {
		pos += r * stp;
		stp *= 1.06;
		vec4 cl = PROJECTION_MATRIX * vec4(pos, 1.0);
		vec2 uv = cl.xy / cl.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;
		float d = texture(depth_tex, uv).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
		vp.xyz /= vp.w;
		float dz = vp.z - pos.z;     // > 0: a cena está na frente do raio
		if (dz > 0.0 && dz < 0.35) {
			// refino binário: tira o degrau do passo
			vec3 a = pos - r * stp;
			vec3 b = pos;
			for (int j = 0; j < 5; j++) {
				vec3 m = (a + b) * 0.5;
				vec4 cm = PROJECTION_MATRIX * vec4(m, 1.0);
				vec2 um = cm.xy / cm.w * 0.5 + 0.5;
				vec4 vm = INV_PROJECTION_MATRIX * vec4(um * 2.0 - 1.0, texture(depth_tex, um).r, 1.0);
				if (vm.z / vm.w - m.z > 0.0) b = m; else a = m;
			}
			vec4 cb = PROJECTION_MATRIX * vec4(b, 1.0);
			uv = cb.xy / cb.w * 0.5 + 0.5;
			pos = b;
			hit_col = textureLod(screen_tex, uv, 0.0).rgb;
			hit = 1.0 - smoothstep(0.5, 2.2, length(pos - v0));
			break;
		}
	}
	if (hit < 0.01) discard;
	ALBEDO = hit_col * tint;
	ALPHA = hit * wet * strength;
#endif
}
