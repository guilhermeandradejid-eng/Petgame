// Céu de fim de tarde em estilo gibi: degradê em faixas suaves, sol com contorno
// e halos em anéis, raios girando devagar e fiapos de nuvem altos (cirros).
shader_type sky;
render_mode use_debanding;

uniform vec4 top : source_color = vec4(0.2, 0.42, 0.9, 1.0);
uniform vec4 mid : source_color = vec4(0.52, 0.72, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.78, 0.62, 1.0);
uniform vec4 blush : source_color = vec4(1.0, 0.66, 0.7, 1.0);
uniform vec4 bottom : source_color = vec4(1.0, 0.86, 0.72, 1.0);
uniform vec3 sun_dir = vec3(-0.55, 0.11, -0.83);
uniform float night = 0.0;                         // arena NOITE: luar, estrelas e lua
uniform vec3 moon_dir = vec3(0.42, 0.32, -0.85);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	float y = EYEDIR.y;
	// degradê com leve posterização (faixas de gibi)
	float k = smoothstep(0.0, 0.75, y);
	float kb = floor(k * 7.0) / 7.0;
	k = mix(k, kb, 0.08);
	vec3 col = mix(horizon.rgb, mid.rgb, smoothstep(0.0, 0.3, k));
	col = mix(col, top.rgb, smoothstep(0.3, 1.0, k));
	col = mix(col, blush.rgb, (1.0 - smoothstep(0.0, 0.09, y)) * 0.2);
	col = mix(bottom.rgb, col, smoothstep(-0.05, 0.02, y));
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	// brilho quente em volta do sol + halos em anel
	col = mix(col, vec3(1.0, 0.75, 0.45), smoothstep(0.7, 1.0, d) * 0.5 * smoothstep(-0.1, 0.3, y + 0.2));
	float halo1 = smoothstep(0.975, 0.977, d) * (1.0 - smoothstep(0.979, 0.981, d));
	float halo2 = smoothstep(0.955, 0.957, d) * (1.0 - smoothstep(0.9585, 0.9605, d));
	col = mix(col, vec3(1.0, 0.93, 0.72), halo1 * 0.16 + halo2 * 0.08);
	// raios de gibi girando
	vec3 side = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(side, s);
	float ang = atan(dot(EYEDIR, upv), dot(EYEDIR, side));
	float rays = 0.0;   // céu limpo, sem raios desenhados
	col = mix(col, vec3(1.0, 0.92, 0.65), rays);
	// cirros: fiapos altos esticados na horizontal
	if (y > 0.04) {
		vec2 uv = EYEDIR.xz / (y + 0.12);
		uv = vec2(uv.x * 0.55, uv.y * 2.6);
		float n = vnoise(uv * 1.3) * 0.65 + vnoise(uv * 3.1 + 7.0) * 0.35;
		float wisp = smoothstep(0.62, 0.74, n) * smoothstep(0.04, 0.16, y) * (1.0 - smoothstep(0.45, 0.8, y));
		vec3 wc = mix(vec3(1.0, 0.97, 0.94), vec3(1.0, 0.85, 0.65), smoothstep(0.6, 1.0, d));
		col = mix(col, wc, wisp * 0.5);
	}
	// sol: contorno laranja escuro, disco e miolo claro
	col = mix(col, vec3(0.93, 0.45, 0.2), smoothstep(0.9905, 0.9915, d));
	col = mix(col, vec3(1.0, 0.84, 0.42), smoothstep(0.9925, 0.9932, d));
	col = mix(col, vec3(1.0, 0.98, 0.86), smoothstep(0.9968, 0.9976, d));
	if (night > 0.5) {
		// céu noturno de gibi: faixas de azul-marinho, brilho no horizonte da cidade,
		// estrelas piscando e lua cheia com halo
		float kk = smoothstep(-0.02, 0.6, y);
		vec3 n = mix(vec3(0.16, 0.14, 0.34), vec3(0.05, 0.08, 0.24), smoothstep(0.0, 0.25, kk));
		n = mix(n, vec3(0.02, 0.03, 0.11), smoothstep(0.25, 1.0, kk));
		n = mix(n, floor(n * 24.0) / 24.0, 0.25);
		n = mix(vec3(0.03, 0.04, 0.1), n, smoothstep(-0.05, 0.02, y));
		if (y > 0.02) {
			vec2 g = EYEDIR.xz / (y + 0.35) * 70.0;
			vec2 cell = floor(g);
			float h = hash(cell);
			vec2 fp = fract(g) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
			float star = step(0.93, h) * (1.0 - smoothstep(0.03, 0.11, length(fp)));
			float tw = 0.6 + 0.4 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
			n += vec3(0.9, 0.92, 1.0) * star * tw * smoothstep(0.02, 0.2, y);
		}
		vec3 m = normalize(moon_dir);
		float md = dot(EYEDIR, m);
		n = mix(n, vec3(0.3, 0.36, 0.6), smoothstep(0.86, 1.0, md) * 0.5);
		float mh = smoothstep(0.975, 0.977, md) * (1.0 - smoothstep(0.979, 0.981, md));
		n = mix(n, vec3(0.7, 0.78, 1.0), mh * 0.12);
		n = mix(n, vec3(0.55, 0.6, 0.8), smoothstep(0.9965, 0.9972, md));
		n = mix(n, vec3(1.0, 0.98, 0.9), smoothstep(0.9975, 0.998, md));
		// crateras
		vec3 side2 = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
		vec2 mu = vec2(dot(EYEDIR, side2), dot(EYEDIR, cross(side2, m))) * 30.0;
		float cr = smoothstep(0.35, 0.3, length(mu - vec2(0.3, 0.25))) + smoothstep(0.22, 0.18, length(mu - vec2(-0.35, -0.1)));
		n = mix(n, vec3(0.86, 0.85, 0.82), cr * smoothstep(0.9978, 0.9982, md) * 0.6);
		col = n;
	}
	COLOR = col;
}
