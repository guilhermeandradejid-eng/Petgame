shader_type canvas_item;
// Céu do crepúsculo: degradê em faixas com dithering, estrelas piscando, nuvens e aurora (clima).

uniform float time = 0.0;
uniform vec2 cam = vec2(0.0, -110.0);
uniform float flash = 0.0;
uniform float weather = 0.0;
uniform float weather_k = 1.0;

const vec3 C0 = vec3(0.043, 0.039, 0.141);
const vec3 C1 = vec3(0.114, 0.090, 0.282);
const vec3 C2 = vec3(0.290, 0.165, 0.431);
const vec3 C3 = vec3(0.635, 0.278, 0.478);
const vec3 C4 = vec3(0.941, 0.541, 0.416);
const vec3 C5 = vec3(1.000, 0.788, 0.541);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0)); int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

vec3 ramp(float h) {
	// h: 0 topo, 1 horizonte
	vec3 cols[6] = vec3[6](C0, C1, C2, C3, C4, C5);
	float stops[6] = float[6](0.0, 0.3, 0.55, 0.75, 0.9, 1.0);
	vec3 c = C0;
	for (int i = 0; i < 5; i++) {
		float t = clamp((h - stops[i]) / (stops[i + 1] - stops[i]), 0.0, 1.0);
		if (h >= stops[i]) c = mix(cols[i], cols[i + 1], t);
	}
	return c;
}

void fragment() {
	vec2 res = vec2(640.0, 360.0);
	vec2 p = UV * res;                       // pixel de arte
	vec2 pp = floor(p);
	float world_y = (p.y - 180.0) + cam.y * 0.08;
	float h = clamp((world_y + 260.0) / 330.0, 0.0, 1.0);
	// quantiza em faixas com dithering ordenado (visual pixel art)
	float steps = 22.0;
	float d = bayer4(pp) - 0.5;
	float hq = floor(h * steps + d * 0.9) / steps;
	vec3 col = ramp(hq);
	// estrelas
	vec2 sp = floor((p + vec2(cam.x * 0.02, cam.y * 0.04)) / 2.0);
	float st = hash(sp);
	float tw = 0.5 + 0.5 * sin(time * (1.0 + hash(sp + 3.1) * 4.0) + st * 40.0);
	float star_mask = step(0.993, st) * (1.0 - smoothstep(0.35, 0.75, h));
	col = mix(col, vec3(1.0, 0.95, 0.85), star_mask * tw);
	// nuvens finas
	float n = noise(vec2((p.x + cam.x * 0.05) * 0.012 + time * 0.01, p.y * 0.05));
	float n2 = noise(vec2((p.x + cam.x * 0.05) * 0.03 - time * 0.02, p.y * 0.11));
	float cloud = smoothstep(0.62, 0.8, n * 0.7 + n2 * 0.4) * smoothstep(0.45, 0.8, h) * (1.0 - smoothstep(0.92, 1.0, h));
	col = mix(col, mix(C3, C5, 0.4), floor(cloud * 3.0 + d * 0.5) / 3.0 * 0.5);
	// aurora (clima 2)
	float aur = 0.0;
	if (weather > 1.5) {
		float x = (p.x + cam.x * 0.03) * 0.012;
		float band = sin(x * 3.0 + time * 0.4 + noise(vec2(x, time * 0.1)) * 3.0) * 30.0 + 90.0;
		float dy = abs(p.y - band);
		aur = (1.0 - smoothstep(0.0, 40.0, dy)) * (0.6 + 0.4 * noise(vec2(x * 4.0, p.y * 0.05 - time * 0.3)));
		aur *= weather_k * (1.0 - smoothstep(0.4, 0.7, h));
		vec3 ac = mix(vec3(0.35, 1.0, 0.75), vec3(0.6, 0.5, 1.0), smoothstep(-20.0, 30.0, p.y - band));
		col += ac * floor(aur * 4.0 + d) / 4.0 * 0.45;
	}
	// chuva de estrelas (clima 1): céu um pouco mais azul e brilhante
	if (weather > 0.5 && weather < 1.5) {
		col = mix(col, col * vec3(0.9, 0.95, 1.15) + vec3(0.0, 0.01, 0.03), weather_k);
	}
	col = mix(col, vec3(0.8, 0.9, 1.0), flash * 0.55);
	COLOR = vec4(col, 1.0) * COLOR;
}
