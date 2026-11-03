// Pós-processamento da imagem 3D (aplicado no SubViewportContainer de cada jogador).
// Tudo num passe só, barato o bastante para celular, com cada efeito ligável:
//  (o bloom é o glow do próprio Godot, no WorldEnvironment: blur gaussiano em vários níveis)
//  - raios de sol (god rays) saindo do sol de fim de tarde
//  - correção de cor: exposição, contraste, saturação e tons divididos (sombras lilás, luz dourada)
//  - nitidez leve (compensa a suavização do MSAA e da escala de resolução)
//  - aberração cromática e zoom radial nas pancadas (smash, especial)
//  - flash de impacto, vinheta, granulado de filme
//  - visual de replay (filme antigo leve) e desfoque na pausa
shader_type canvas_item;
render_mode unshaded;

uniform int quality = 2;                 // 0 baixo, 1 médio, 2 alto
uniform float rays_amount = 0.35;
uniform vec2 sun_uv = vec2(-1.0);        // posição do sol na tela (0..1); fora = sem raios
uniform float sun_vis = 0.0;
uniform float exposure = 1.0;
uniform float contrast = 1.08;
uniform float saturation = 1.12;
uniform vec3 shadow_tint = vec3(0.92, 0.9, 1.06);
uniform vec3 highlight_tint = vec3(1.05, 1.0, 0.92);
uniform float sharpen = 0.25;
uniform float vignette = 0.32;
uniform float grain = 0.0;
uniform float chroma = 0.0;              // aberração cromática base
uniform float impact = 0.0;              // pulso das pancadas (0..1)
uniform vec2 impact_uv = vec2(0.5);
uniform float flash = 0.0;               // flash branco/quente do golpe especial
uniform float replay = 0.0;              // visual de replay
uniform float blur = 0.0;                // desfoque da pausa
uniform float time_s = 0.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 cen = uv - 0.5;

	// zoom radial nas pancadas: puxa a imagem na direção do ponto de impacto
	float zb = impact * impact * 0.025;
	vec3 col;
	if (zb > 0.001 && quality > 0) {
		vec2 dir = uv - impact_uv;
		col = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float k = float(i) / 5.0;
			col += texture(TEXTURE, uv - dir * zb * k).rgb;
		}
		col /= 6.0;
	} else {
		col = texture(TEXTURE, uv).rgb;
	}

	// aberração cromática (cresce para as bordas)
	float ca = chroma + impact * 0.5;
	if (ca > 0.001) {
		vec2 off = cen * ca * 0.012;
		col.r = mix(col.r, texture(TEXTURE, uv + off).r, 0.85);
		col.b = mix(col.b, texture(TEXTURE, uv - off).b, 0.85);
	}

	// desfoque da pausa (9 amostras em dois anéis)
	if (blur > 0.001) {
		vec3 b = col;
		float r = blur * 6.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 o = vec2(cos(a), sin(a)) * px * r;
			b += texture(TEXTURE, uv + o).rgb + texture(TEXTURE, uv + o * 2.2).rgb;
		}
		col = mix(col, b / 17.0, clamp(blur, 0.0, 1.0));
	}

	// nitidez (unsharp mask em cruz)
	if (sharpen > 0.001 && quality > 0 && blur < 0.01) {
		vec3 n = texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb + texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb
			+ texture(TEXTURE, uv + vec2(0.0, px.y)).rgb + texture(TEXTURE, uv - vec2(0.0, px.y)).rgb;
		col = max(col + (col - n * 0.25) * sharpen, vec3(0.0));
	}

	// raios de sol: amostras em direção ao sol, só do céu claro
	if (rays_amount > 0.001 && sun_vis > 0.001 && quality >= 1) {
		vec2 d = (sun_uv - uv);
		float dl = length(d * vec2(1.0, px.x / px.y));
		int steps = quality >= 2 ? 12 : 6;
		vec3 acc = vec3(0.0);
		float decay = 1.0;
		vec2 st = d / float(steps) * 0.55;
		vec2 p = uv;
		for (int i = 0; i < 12; i++) {
			if (i >= steps) { break; }
			p += st;
			vec3 s = texture(TEXTURE, clamp(p, vec2(0.001), vec2(0.999))).rgb;
			acc += smoothstep(0.82, 1.0, luma(s)) * s * decay;
			decay *= 0.86;
		}
		acc /= float(steps);
		float fall = 1.0 - smoothstep(0.0, 0.9, dl);
		col += acc * rays_amount * sun_vis * fall * vec3(1.0, 0.82, 0.55) * 1.6;
	}

	// correção de cor
	col *= exposure;
	float l = luma(col);
	col = mix(col * shadow_tint, col * highlight_tint, smoothstep(0.15, 0.85, l));
	col = (col - 0.5) * contrast + 0.5;
	col = mix(vec3(luma(col)), col, saturation);
	// "tone map" suave só no topo, para o bloom não estourar o branco
	col = col / (1.0 + max(col - 0.85, vec3(0.0)) * 1.4);

	// flash do golpe especial
	col = mix(col, vec3(1.0, 0.95, 0.82), clamp(flash, 0.0, 1.0) * 0.4);

	// replay: menos saturado, quente, com faixas pretas e granulado
	if (replay > 0.001) {
		vec3 sep = vec3(luma(col)) * vec3(1.08, 0.98, 0.84);
		col = mix(col, mix(col, sep, 0.3), replay);
		float bars = step(abs(cen.y), 0.5 - 0.07 * replay);
		col *= mix(1.0, bars, replay);
	}

	// vinheta
	float v = dot(cen * vec2(1.0, 0.85), cen * vec2(1.0, 0.85));
	col *= 1.0 - smoothstep(0.12, 0.62, v) * (vignette + impact * 0.1 + replay * 0.15);

	// granulado de filme
	float gr = grain + replay * 0.025;
	if (gr > 0.001) {
		float n = hash12(FRAGCOORD.xy + fract(time_s * 13.7) * 1000.0) - 0.5;
		col += n * gr * (1.0 - l * 0.5);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
