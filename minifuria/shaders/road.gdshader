shader_type spatial;
render_mode cull_disabled;
// Pista procedural: UV.x = 0..1 na largura, UV.y = metros ao longo da pista.
// mode 0 asfalto, 1 plástico laranja (brinquedo), 2 asfalto com gelo, 3 placas de metal.
uniform float W = 22.0;
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool two_way = true;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}
// relevo do agregado (pedrinhas) para o normal map
float grit(vec2 q) {
	return noise(q * 9.0) * 0.55 + hash(floor(q * 30.0)) * 0.45;
}

void fragment() {
	float x = UV.x * W;
	float y = UV.y;
	vec2 q = vec2(x, y);
	float big = fbm(q * 0.11);
	float mid = noise(q * 1.3);
	float edge_ao = smoothstep(0.0, 1.8, min(x, W - x));     // escurece perto da zebra
	vec3 c;
	float rough = 0.8;
	float spec = 0.4;
	float bump = 0.0;
	float metal = 0.0;
	if (mode == 1) {
		// plástico de pista de brinquedo: liso, brilhante, com riscos finos e emendas de molde
		c = vec3(1.0, 0.43, 0.06) * (0.94 + big * 0.1);
		float scratch = smoothstep(0.985, 1.0, noise(vec2(x * 0.4, y * 6.0))) * 0.25;
		c *= 1.0 - scratch;
		float seam = smoothstep(0.03, 0.0, abs(fract(y / 12.0) - 0.5) - 0.48);
		c *= 1.0 - 0.18 * seam;
		float stripe = step(abs(x - W * 0.5), 0.25) * step(fract(y / 6.0), 0.55);
		c = mix(c, vec3(1.0, 0.96, 0.88), stripe);
		float side = step(abs(x - 1.2), 0.15) + step(abs(x - (W - 1.2)), 0.15);
		c = mix(c, vec3(1.0, 0.72, 0.22), side);
		rough = 0.22;
		spec = 0.7;
		bump = 0.15;
	} else if (mode == 3) {
		// chapas de aço com relevo "diamante", parafusos e ferrugem nas emendas
		vec2 cell = q / vec2(W / 4.0, 4.0);
		vec2 g = fract(cell);
		float seam = smoothstep(0.035, 0.0, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)) - 0.004);
		vec2 dq = fract(mat2(vec2(0.7, 0.7), vec2(-0.7, 0.7)) * q * 2.2);
		float diamond = smoothstep(0.15, 0.0, abs(dq.x - 0.5) - 0.32) * smoothstep(0.4, 0.0, abs(dq.y - 0.5) - 0.06);
		float shade = hash(floor(cell)) * 0.12;
		c = vec3(0.4, 0.41, 0.45) * (0.82 + big * 0.3 + shade);
		c = mix(c, vec3(0.55, 0.56, 0.6), diamond * 0.5);
		float rust = smoothstep(0.62, 0.8, fbm(q * 0.35 + 4.0)) * (0.4 + seam);
		c = mix(c, vec3(0.42, 0.24, 0.14), clamp(rust, 0.0, 0.7));
		c *= 1.0 - 0.5 * seam;
		float bolt = smoothstep(0.035, 0.02, length(g - vec2(0.06, 0.1))) + smoothstep(0.035, 0.02, length(g - vec2(0.94, 0.1)));
		c = mix(c, vec3(0.75), bolt);
		rough = 0.42 - diamond * 0.12 + rust * 0.4;
		spec = 0.6;
		metal = 0.55 * (1.0 - rust);
		bump = diamond * 0.8 + bolt;
	} else {
		// asfalto: base escura com manchas grandes, agregado fino claro e pedrinhas
		float g = grit(q);
		c = vec3(0.19, 0.2, 0.215) * (0.8 + big * 0.42);
		c *= 0.9 + mid * 0.16;
		c += vec3(0.05) * (g - 0.5);
		float stones = step(0.94, hash(floor(q * 26.0) + 3.0));
		c = mix(c, vec3(0.42, 0.41, 0.4), stones * 0.55);
		// trilhas dos pneus: mais escuras e lisas no meio de cada faixa
		float lane_w = W / (two_way ? 4.0 : 3.0);
		float lx = fract(x / lane_w);
		float wheel = exp(-pow((lx - 0.3) * 7.0, 2.0)) + exp(-pow((lx - 0.7) * 7.0, 2.0));
		float rub = wheel * (0.55 + 0.45 * noise(vec2(x * 2.0, y * 0.15)));
		c *= 1.0 - 0.22 * rub;
		// trincas finas e borracha de freada esparsa
		float crack = smoothstep(0.009, 0.0, abs(noise(q * 0.55 + 11.0) - 0.5)) * smoothstep(0.68, 0.8, noise(q * 0.07 + 2.0));
		c *= 1.0 - 0.28 * crack;
		float skid = smoothstep(0.78, 0.9, noise(vec2(x * 0.25, y * 0.03) + 5.0)) * wheel;
		c *= 1.0 - 0.3 * skid;
		rough = 0.86 - rub * 0.2 - skid * 0.15;
		spec = 0.38 + rub * 0.12;
		bump = g * (1.0 - rub * 0.6) + stones * 0.6 - crack * 0.8;
		if (mode == 2) {
			float ice = smoothstep(0.55, 0.75, noise(q * 0.08 + 3.0));
			float frost = smoothstep(0.4, 0.9, noise(q * 1.7)) * 0.25;
			c = mix(c, vec3(0.8, 0.88, 1.0), ice * 0.7 + frost * 0.3);
			rough = mix(rough, 0.12, ice);
			spec = mix(spec, 0.85, ice);
			bump *= 1.0 - ice * 0.8;
		}
		// pintura: gasta nas bordas da tinta e onde os pneus passam
		float wear = smoothstep(0.25, 0.65, noise(q * 3.5) * 0.6 + noise(q * 0.7) * 0.6) * (1.0 - 0.6 * rub);
		vec3 paint = vec3(0.93, 0.92, 0.88);
		float edge = step(0.5, x) * step(x, 0.85) + step(W - 0.85, x) * step(x, W - 0.5);
		float cx = abs(x - W * 0.5);
		float dash = step(fract(y / 11.0), 0.5);
		float lane;
		vec3 mid_col;
		float midl;
		if (two_way) {
			midl = step(0.2, cx) * step(cx, 0.42);
			mid_col = vec3(1.0, 0.74, 0.14);
			lane = (step(abs(x - W * 0.25), 0.12) + step(abs(x - W * 0.75), 0.12)) * dash;
		} else {
			midl = step(cx, 0.14) * dash;
			mid_col = paint;
			lane = 0.0;
		}
		float pm = clamp(edge + lane, 0.0, 1.0) * wear;
		c = mix(c, paint, pm);
		c = mix(c, mid_col, midl * wear);
		rough = mix(rough, 0.6, max(pm, midl * wear));
		bump = mix(bump, 0.75, max(pm, midl * wear) * 0.6);
	}
	c *= tint.rgb;
	c *= mix(0.7, 1.0, edge_ao);
	// relevo fino por diferenças do "grit" (normal map tangente)
	float e = 0.03;
	float h0 = grit(q);
	float hx = grit(q + vec2(e, 0.0));
	float hy = grit(q + vec2(0.0, e));
	float str = (mode == 1) ? 0.25 : ((mode == 3) ? 0.6 : 1.0);
	vec3 nm = normalize(vec3((h0 - hx) * str * 1.4, (h0 - hy) * str * 1.4, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.9 + bump * 0.3;
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
}
