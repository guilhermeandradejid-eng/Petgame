shader_type canvas_item;
// Pós-processamento de tela: blur radial, aberração cromática, linhas de velocidade, vinheta, flash e saturação.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float aberr = 0.0;
uniform float lines = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float vig = 0.3;
uniform float sat = 1.1;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.777;
// lens flare: até 12 fontes de luz na tela (xy = posição, z = força, w = tamanho) + o sol
uniform vec4 fl_pos[12];
uniform vec4 fl_col[12];
uniform int fl_n = 0;
uniform vec2 sun_uv = vec2(-2.0, -2.0);
uniform float sun_k = 0.0;
uniform vec4 sun_col : source_color = vec4(1.0, 0.9, 0.7, 1.0);

float hash(float p) { return fract(sin(p * 91.7) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	vec2 da = vec2(d.x * aspect, d.y);
	float r = length(da);
	float amt = blur * smoothstep(0.1, 0.8, r);
	vec3 col;
	if (blur > 0.003 || aberr > 0.003) {
		// só paga as 6 amostras quando há blur/aberração (nitro, batida, câmera lenta)
		col = vec3(0.0);
		vec2 ab = d * aberr * 0.008;
		for (int i = 0; i < 6; i++) {
			float k = float(i) / 5.0;
			vec2 u = uv - d * amt * k * 0.05;
			col.r += texture(screen_tex, u + ab).r;
			col.g += texture(screen_tex, u).g;
			col.b += texture(screen_tex, u - ab).b;
		}
		col /= 6.0;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	// linhas de velocidade (estilo anime), saindo do carro
	float ang = atan(da.y, da.x);
	float cell = floor(ang * 38.0);
	float h = hash(cell);
	float thin = smoothstep(0.5, 0.0, abs(fract(ang * 38.0) - 0.5) * 2.0 - 0.0);
	float flick = step(0.55, hash(cell + floor(TIME * 18.0)));
	float ln = step(0.6, h) * flick * smoothstep(0.35 + h * 0.2, 0.95, r) * thin;
	if (lines > 0.01) {
		col += vec3(1.0) * ln * lines * 0.55;
	}
	// lens flare: halo + risco anamórfico horizontal + "fantasmas" refletidos pelo centro da lente
	vec2 c0 = vec2(0.5);
	for (int i = 0; i < 12; i++) {
		if (i >= fl_n) {
			break;
		}
		vec2 p = fl_pos[i].xy;
		float k = fl_pos[i].z;
		float sz = fl_pos[i].w;
		vec2 dd = uv - p;
		dd.x *= aspect;
		float r = length(dd);
		float halo = exp(-r / (0.013 * sz)) * 0.8 + exp(-r / (0.05 * sz)) * 0.12;
		float streak = exp(-abs(dd.y) / (0.0022 * sz)) * exp(-abs(dd.x) / (0.2 * sz));
		vec3 fc = fl_col[i].rgb;
		col += fc * halo * k + mix(fc, vec3(0.55, 0.75, 1.0), 0.6) * streak * k * 0.4;
		for (int g = 0; g < 3; g++) {
			float gk = (g == 0) ? 0.45 : ((g == 1) ? 0.85 : 1.35);
			vec2 gp = c0 + (c0 - p) * gk;
			vec2 gd = uv - gp;
			gd.x *= aspect;
			float gr = (g == 0) ? 0.03 : ((g == 1) ? 0.055 : 0.02);
			gr *= sz;
			float disk = smoothstep(gr, gr * 0.6, length(gd));
			vec3 gcol = (g == 0) ? vec3(0.4, 0.9, 0.6) : ((g == 1) ? vec3(0.6, 0.5, 1.0) : vec3(1.0, 0.6, 0.3));
			col += gcol * fc * disk * k * 0.07;
		}
	}
	// brilho do sol entrando pela borda (dia) com fantasmas atravessando a tela
	if (sun_k > 0.0) {
		vec2 sd = uv - sun_uv;
		sd.x *= aspect;
		float sr = length(sd);
		col += sun_col.rgb * exp(-sr / 0.35) * sun_k * 0.35;
		for (int g = 0; g < 4; g++) {
			float gk = 0.3 + float(g) * 0.42;
			vec2 gp = c0 + (c0 - sun_uv) * gk;
			vec2 gd = uv - gp;
			gd.x *= aspect;
			float gr = 0.025 + 0.02 * float(g);
			float ring = smoothstep(gr, gr * 0.75, length(gd)) - smoothstep(gr * 0.75, gr * 0.5, length(gd)) * 0.6;
			col += sun_col.rgb * vec3(0.7 + 0.3 * float(g == 1), 0.8, 1.0 - 0.3 * float(g == 2)) * ring * sun_k * 0.05;
		}
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col *= 1.0 - vig * smoothstep(0.45, 1.1, r);
	col = mix(col, flash.rgb, flash.a);
	COLOR = vec4(col, 1.0);
}
