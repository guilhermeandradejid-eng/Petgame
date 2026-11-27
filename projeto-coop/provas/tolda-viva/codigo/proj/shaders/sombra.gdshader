// Sombra de contato + sombra da mão e da manga do bonequeiro (regra 12): multiplica por uma tinta.
// O braço sai do boneco em direção à frente do palco (onde o bonequeiro fica, embaixo da tolda).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mul, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.55, 0.7);
uniform float braco = 1.0;   // 0 = só contato (inimigos)
uniform float forca = 1.0;
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(a, b, f.x);
}
void fragment() {
	// UV: x -1..1 largura; y 0 (pé) .. 1 (ponta do braço, para a frente)
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y);
	// contato: elipse no pé (y ~ 0.1)
	float e = length(vec2(p.x, (p.y - 0.09) * 4.2));
	float a = atan(p.y - 0.09, p.x);
	float m = step(e, 0.9 + 0.06 * (vn(vec2(a * 5.0, 1.0)) - 0.5));
	// braço: punho estreito junto do boneco, manga larga mais à frente, com borda rasgada
	float w = mix(0.16, 0.42, smoothstep(0.12, 0.55, p.y)) + 0.03 * sin(p.y * 22.0);
	float arm = step(abs(p.x + 0.08 * p.y), w) * step(0.12, p.y) * step(p.y, 0.98) * braco;
	float soft = 1.0 - 0.45 * smoothstep(0.3, 0.98, p.y);
	float v = max(m, arm * 0.55 * soft);
	ALBEDO = mix(vec3(1.0), shadow_tint, v * forca);
}
