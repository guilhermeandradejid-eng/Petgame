// Parede do armazém revestida de azulejo: barra azul-noite embaixo, friso de corda, padrão de
// folha em quadrante (4 azulejos fecham a roseta), painel figurativo emoldurado, placa pintada,
// salitre subindo da base como umidade de verdade, reboco caiado em cima.
shader_type spatial;
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D painel : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D placa : source_color, filter_linear_mipmap, repeat_disable;
uniform float T = 0.25;
uniform float grout = 0.011;
uniform vec4 painel_rect = vec4(-2.0, 1.25, 2.0, 1.0);  // x0, y0, largura, altura
uniform vec4 placa_rect = vec4(1.5, 1.75, 2.0, 0.5);
uniform vec2 porta = vec2(4.25, 5.75);                  // vão da porta em x
uniform float porta_h = 2.5;
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.54, 0.80);
uniform vec3 rejunte : source_color = vec3(0.678, 0.647, 0.584);
uniform vec3 reboco : source_color = vec3(0.90, 0.88, 0.82);
uniform vec3 escuro : source_color = vec3(0.07, 0.08, 0.15);
uniform vec3 sky_col : source_color = vec3(0.80, 0.86, 1.0);
uniform vec3 base_col : source_color = vec3(0.937, 0.914, 0.863);
uniform float pat_mix = 0.45;    // azulejo de padrão misturado ao estanho: o fundo não compete com a ação
uniform float barra_mix = 0.55;  // a faixa de losangos da base perde saturação
uniform float ao_h = 0.32;       // AO pintado na base da parede (m)

varying vec3 wpos;
varying float v_spec;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

vec3 atl(float idx, vec2 uv) {
	vec2 cell = vec2(mod(idx, 4.0), floor(idx / 4.0));
	return texture(atlas, (cell + clamp(uv, 0.004, 0.996)) / vec2(4.0, 2.0)).rgb;
}

void fragment() {
	vec2 p = vec2(wpos.x, wpos.y);
	vec2 tid = floor(p / T);
	vec2 uv = p / T - tid;
	uv.y = 1.0 - uv.y;
	float h1 = hash(tid), h2 = hash(tid + 5.1);
	vec2 dd = min(uv, 1.0 - uv);
	float gw = grout / T * 0.5;
	float gm = 1.0 - smoothstep(gw * 0.75, gw * 1.35, min(dd.x, dd.y) + (fbm(p * 90.0) - 0.5) * gw * 0.5);
	vec3 col;
	float tiled = 1.0;
	float row = tid.y;
	if (p.y < 0.75) {
		col = atl(4.0 + floor(h1 * 2.0), uv);
		float lb = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, mix(vec3(lb), base_col * 0.8, 0.35), barra_mix);
	} else if (p.y < 1.0 || (p.y >= 3.25 && p.y < 3.5)) {
		col = mix(atl(6.0 + mod(tid.x, 2.0), uv), base_col, pat_mix * 0.6);
	} else if (p.y < 3.25) {
		// quadrante: gira o azulejo conforme a paridade para a roseta fechar nos cantos
		vec2 q = uv;
		float px = mod(tid.x, 2.0), py = mod(tid.y, 2.0);
		if (px > 0.5) q.x = 1.0 - q.x;
		if (py < 0.5) q.y = 1.0 - q.y;
		col = mix(atl(floor(h1 * 4.0), q), base_col, pat_mix);
	} else {
		tiled = 0.0;
		float n = fbm(p * vec2(3.0, 9.0));
		col = reboco * (0.94 + 0.08 * n);
		// manchas de cal escorrida e uma faixa pintada no alto da barra
		col *= 1.0 - 0.05 * smoothstep(0.55, 0.8, fbm(p * vec2(1.2, 0.4)));
		if (p.y < 3.6) col = mix(col, vec3(0.263, 0.388, 0.682), 0.85);
	}
	// moldura de corda em volta do painel e o próprio painel
	vec4 pr = painel_rect;
	if (p.x >= pr.x - T && p.x < pr.x + pr.z + T && p.y >= pr.y - T && p.y < pr.y + pr.w + T) {
		if (p.x >= pr.x && p.x < pr.x + pr.z && p.y >= pr.y && p.y < pr.y + pr.w) {
			vec2 puv = vec2((p.x - pr.x) / pr.z, 1.0 - (p.y - pr.y) / pr.w);
			col = texture(painel, puv).rgb;
		} else {
			bool vert = p.x < pr.x || p.x >= pr.x + pr.z;
			col = atl(6.0 + mod(tid.x + tid.y, 2.0), vert ? vec2(uv.y, 1.0 - uv.x) : uv);
		}
	}
	vec4 sr = placa_rect;
	if (p.x >= sr.x && p.x < sr.x + sr.z && p.y >= sr.y && p.y < sr.y + sr.w) {
		vec2 suv = vec2((p.x - sr.x) / sr.z, 1.0 - (p.y - sr.y) / sr.w);
		col = texture(placa, suv).rgb;
	}
	col *= 0.97 + 0.05 * h2;
	col = mix(col, rejunte * (0.9 + 0.12 * vn(p * 40.0)), gm * tiled);
	// salitre subindo da base: eflorescência granulada que sobe mais onde a parede é mais úmida
	float rise = 0.05 + 0.5 * smoothstep(0.45, 0.8, fbm(vec2(p.x * 0.5, 3.1)));
	float salt = smoothstep(0.0, 0.05, rise - p.y + (fbm(p * 7.0) - 0.5) * 0.3) * step(0.35, vn(p * 18.0) * 0.5 + fbm(p * 3.0) * 0.7);
	float grain = step(0.5, vn(p * 150.0) * 0.6 + vn(p * 45.0) * 0.4);
	col = mix(col, mix(vec3(0.824, 0.820, 0.784), vec3(0.62, 0.61, 0.57), grain * 0.6), salt * 0.9);
	// AO pintado junto ao chão: escurece 20% nos últimos ~30 cm, em aguada (degraus de pincel, não degradê liso)
	float ao = 1.0 - smoothstep(0.0, ao_h, p.y + (fbm(p * vec2(4.0, 1.0)) - 0.5) * 0.08);
	ao = floor(ao * 3.0 + 0.5) / 3.0;
	col *= 1.0 - 0.2 * ao;
	// vão da porta (escuro do armazém)
	if (p.x > porta.x && p.x < porta.y && p.y < porta_h) col = escuro;
	ALBEDO = col;
	v_spec = (1.0 - gm) * tiled * (1.0 - salt);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = sky_col * 0.05 * (0.4 + 1.2 * hash(tid + 2.0)) * v_spec * (0.4 + fres);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sh = smoothstep(0.35, 0.65, ATTENUATION);
	float lit = smoothstep(-0.02, 0.02, ndl) * sh;
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
