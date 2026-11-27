// Nuvem de serragem em flipbook (v2): 4 quadros a 12 por segundo. A forma é uma bola de lóbulos
// que incha e se desfaz por erosão (limiar sobe a cada quadro); 2 tons de serragem, borda fina.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor_a : source_color = vec3(0.93, 0.83, 0.66);
uniform vec3 cor_b : source_color = vec3(0.74, 0.58, 0.42);
uniform float quadro = 0.0;   // 0..3 (inteiro)
uniform float sem = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + sem * 13.0) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float q = quadro;
	float R = mix(0.5, 0.95, q / 3.0);
	float a = atan(p.y, p.x);
	float lob = 0.12 * sin(a * 5.0 + sem * 6.0) + 0.07 * sin(a * 9.0 + sem * 2.0);
	float r = length(p) / R;
	float body = 1.0 - r + lob;
	if (body < 0.0) discard;
	float n = vn(p * 4.5 + sem) * 0.65 + vn(p * 11.0 - sem) * 0.35;
	float er = q / 3.0 * 0.75;                          // erosão por quadro
	if (n * (0.4 + body) < er * 0.9) discard;
	vec3 c = mix(cor_b, cor_a, step(0.1, p.y * -0.6 + p.x * 0.2 + n * 0.5));
	c = mix(c, cor_b * 0.62, step(body, 0.05 + 0.03 * q));
	ALBEDO = c;
}
