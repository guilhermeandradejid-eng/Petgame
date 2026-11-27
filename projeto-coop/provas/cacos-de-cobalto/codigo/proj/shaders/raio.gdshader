// Fita de raio/rastro voltada para a câmera (geometria montada no script).
// UV.x = ao longo, UV.y = através (0..1). Núcleo claro, corpo na cor da matéria, borda azul-noite
// quebrada (forma de pincel, não bolha). COLOR.a = intensidade por vértice.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform vec3 col : source_color = vec3(0.953, 0.776, 0.192);
uniform vec3 core : source_color = vec3(1.0, 0.98, 0.88);
uniform vec3 edge : source_color = vec3(0.114, 0.153, 0.333);
uniform float emit = 2.0;
uniform float edge_w = 0.22;
uniform float dash = 0.0;        // >0: traço interrompido (rastro pintado)
uniform float seed = 0.0;
uniform float fade = 0.0;        // >0: alfa decresce ao longo da fita (rastro de golpe)
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	float y = abs(UV.y * 2.0 - 1.0);
	float n = (vn(vec2(UV.x * 30.0 + seed * 13.0, seed)) - 0.5) * 0.35;
	float w = COLOR.a;
	float body = 1.0 - smoothstep(0.62 + n * 0.5, 0.72 + n * 0.5, y);
	float cor = 1.0 - smoothstep(0.18, 0.3, y + n * 0.3);
	float rim = 1.0 - smoothstep(0.86 + n * 0.4, 0.96 + n * 0.4, y);
	if (dash > 0.0 && fract(UV.x * dash + seed) > 0.72) { body = 0.0; cor = 0.0; rim = 0.0; }
	vec3 c = mix(edge, col, body);
	c = mix(c, core, cor);
	float a = max(rim * 0.95, body) * w * (1.0 - fade * UV.x);
	if (a < 0.02) discard;
	ALBEDO = c;
	ALPHA = a;
	EMISSION = (col * body + core * cor) * emit * w;
}
