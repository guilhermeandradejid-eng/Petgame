// Cortina de goteira: água que cai de um rasgo do teto em fios recortados (2 tons, sem borrão), virada para a
// câmera só em torno do eixo vertical. Acende fraco quando passa pelo fio de luz fria.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(0.62, 0.72, 0.8);
varying vec3 wp;
void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 to = CAMERA_POSITION_WORLD - c; to.y = 0.0;
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(to)));
	vec3 v = c + r * VERTEX.x * s + vec3(0.0, VERTEX.y, 0.0);
	wp = v;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
}
void fragment() {
	float t = vento.w;
	float col = floor(UV.x * 22.0);
	float h = fract(sin(col * 12.9898) * 43758.5);
	float y = wp.y * 0.55 + t * (6.0 + 3.0 * h) + h * 20.0;
	float gota = step(fract(y * 0.35), 0.32 + 0.25 * h);
	float fio = step(abs(fract(UV.x * 22.0) - 0.5), 0.09 + 0.05 * h);
	float a = fio * gota * (0.45 + 0.35 * h);
	float cabeca = step(fract(y * 0.35), 0.06) * fio;
	float borda = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float alto = 1.0 - smoothstep(18.0, 30.0, wp.y);
	a = max(a, cabeca * 0.9) * borda * alto * step(-0.05, wp.y);
	if (a < 0.02) discard;
	vec3 c = mix(cor, vec3(0.9, 0.96, 1.0), cabeca);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a));
	ALPHA = a;
}
