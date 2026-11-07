shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Ar quente do escape do nitro: distorce o que está atrás (amostra a tela com deslocamento animado).
// Usado em partículas: COLOR.a controla a força de cada "bolha" de calor.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.018;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// sempre de frente para a câmera (funciona por partícula: MODEL_MATRIX já inclui a instância)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV - 0.5;
	float mask = smoothstep(0.5, 0.12, length(c)) * COLOR.a;
	float t = TIME;
	vec2 n = vec2(
		noise(UV * 5.0 + vec2(0.0, t * 6.0)) + noise(UV * 11.0 + vec2(3.1, t * 9.0)) * 0.5,
		noise(UV * 5.0 + vec2(7.3, t * 5.0)) + noise(UV * 11.0 + vec2(1.7, t * 8.0)) * 0.5) - 0.75;
	vec2 off = n * strength * mask;
	vec3 col = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	// um toque de calor (laranja bem leve) no miolo
	col += vec3(0.06, 0.025, 0.0) * mask * mask;
	ALBEDO = col;
	ALPHA = clamp(mask * 1.6, 0.0, 1.0);
}
