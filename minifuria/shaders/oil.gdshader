shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
// Poça de graxa/óleo: mancha irregular que se espalha (spread 0..1), gotas em volta, película
// iridescente que muda com o ângulo de visão e reflexo molhado (rugosidade baixa + normal ondulada).
uniform float strength = 1.0;
uniform float spread = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d) / max(spread, 0.05);
	float ang = atan(d.y, d.x);
	float wob = noise(vec2(cos(ang), sin(ang)) * 2.2 + seed) * 0.45 + noise(UV * 7.0 + seed) * 0.2;
	float body = smoothstep(0.86, 0.78, r + wob * 0.5);
	vec2 g = UV * 10.0 + seed;
	float dots = smoothstep(0.28, 0.12, length(fract(g) - 0.5)) * step(0.8, hash(floor(g))) * smoothstep(1.35, 0.95, r) * (1.0 - body);
	float a = clamp(body + dots, 0.0, 1.0) * strength;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float film = noise(UV * 3.0 + vec2(TIME * 0.06, seed)) * 1.6 + r * 1.2 + fres * 1.5;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (film + vec3(0.0, 0.33, 0.67)));
	float edge = smoothstep(0.45, 0.85, r + wob * 0.5);
	ALBEDO = mix(vec3(0.016, 0.013, 0.01), rainbow * 0.4, 0.22 + edge * 0.3);
	ROUGHNESS = 0.05 + edge * 0.15;
	METALLIC = 0.25;
	SPECULAR = 0.95;
	NORMAL_MAP = vec3(0.5 + (noise(UV * 14.0 + seed) - 0.5) * 0.35, 0.5 + (noise(UV * 14.0 + seed + 5.0) - 0.5) * 0.35, 1.0);
	ALPHA = a * 0.96;
}
