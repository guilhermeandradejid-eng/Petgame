// Céu de fim de tarde em estilo gibi: degradê em faixas suaves, sol com contorno
// e halos em anéis, raios girando devagar e fiapos de nuvem altos (cirros).
shader_type sky;
render_mode use_debanding;

uniform vec4 top : source_color = vec4(0.2, 0.42, 0.9, 1.0);
uniform vec4 mid : source_color = vec4(0.52, 0.72, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.78, 0.62, 1.0);
uniform vec4 blush : source_color = vec4(1.0, 0.66, 0.7, 1.0);
uniform vec4 bottom : source_color = vec4(1.0, 0.86, 0.72, 1.0);
uniform vec3 sun_dir = vec3(-0.55, 0.2, -0.81);

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
	k = mix(k, kb, 0.22);
	vec3 col = mix(horizon.rgb, mid.rgb, smoothstep(0.0, 0.3, k));
	col = mix(col, top.rgb, smoothstep(0.3, 1.0, k));
	col = mix(col, blush.rgb, (1.0 - smoothstep(0.0, 0.09, y)) * 0.35);
	col = mix(bottom.rgb, col, smoothstep(-0.05, 0.02, y));
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	// brilho quente em volta do sol + halos em anel
	col = mix(col, vec3(1.0, 0.75, 0.45), smoothstep(0.7, 1.0, d) * 0.5 * smoothstep(-0.1, 0.3, y + 0.2));
	float halo1 = smoothstep(0.975, 0.977, d) * (1.0 - smoothstep(0.979, 0.981, d));
	float halo2 = smoothstep(0.955, 0.957, d) * (1.0 - smoothstep(0.9585, 0.9605, d));
	col = mix(col, vec3(1.0, 0.93, 0.72), halo1 * 0.35 + halo2 * 0.2);
	// raios de gibi girando
	vec3 side = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(side, s);
	float ang = atan(dot(EYEDIR, upv), dot(EYEDIR, side));
	float rays = step(0.0, sin(ang * 12.0 + TIME * 0.12)) * smoothstep(0.86, 0.975, d) * 0.08;
	col = mix(col, vec3(1.0, 0.92, 0.65), rays);
	// cirros: fiapos altos esticados na horizontal
	if (y > 0.04) {
		vec2 uv = EYEDIR.xz / (y + 0.12);
		uv = vec2(uv.x * 0.55 + TIME * 0.004, uv.y * 2.6);
		float n = vnoise(uv * 1.3) * 0.65 + vnoise(uv * 3.1 + 7.0) * 0.35;
		float wisp = smoothstep(0.62, 0.74, n) * smoothstep(0.04, 0.16, y) * (1.0 - smoothstep(0.45, 0.8, y));
		vec3 wc = mix(vec3(1.0, 0.97, 0.94), vec3(1.0, 0.85, 0.65), smoothstep(0.6, 1.0, d));
		col = mix(col, wc, wisp * 0.5);
	}
	// sol: contorno laranja escuro, disco e miolo claro
	col = mix(col, vec3(0.93, 0.45, 0.2), smoothstep(0.9905, 0.9915, d));
	col = mix(col, vec3(1.0, 0.84, 0.42), smoothstep(0.9925, 0.9932, d));
	col = mix(col, vec3(1.0, 0.98, 0.86), smoothstep(0.9968, 0.9976, d));
	COLOR = col;
}
