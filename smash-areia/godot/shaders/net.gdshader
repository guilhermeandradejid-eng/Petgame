// Rede de beach tennis: malha quadrada com fios suavizados (sem serrilhado),
// leve caimento e tremida quando a bola bate.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 color : source_color = vec4(0.1, 0.08, 0.15, 1.0);
uniform vec2 cells = vec2(92.0, 9.0);
uniform float cord = 0.09;
uniform float hit_amp = 0.0;
uniform float hit_x = 0.0;
uniform float hit_t = 10.0;
uniform float half_w = 4.6;

void vertex() {
	float edge = sin(UV.y * 3.14159);              // presa em cima e embaixo
	float sag = sin(UV.x * 3.14159) * 0.025;       // caimento no meio
	VERTEX.y -= sag * (1.0 - UV.y);
	float d = abs(VERTEX.x - hit_x);
	float wave = sin(hit_t * 22.0 - d * 5.0) * exp(-hit_t * 4.0) * exp(-d * 0.7);
	VERTEX.z += wave * hit_amp * edge * (0.6 + 0.4 * sin(UV.x * 3.14159));
}

void fragment() {
	vec2 g = UV * cells;
	vec2 fw = max(fwidth(g), vec2(1e-4));
	vec2 d = min(fract(g), 1.0 - fract(g));
	vec2 px = d / fw;                       // distância ao fio em pixels
	vec2 w = max(vec2(cord) / fw, vec2(0.7));
	vec2 a = 1.0 - smoothstep(w - 0.6, w + 0.6, px);
	float line = max(a.x, a.y);
	if (line < 0.02) {
		discard;
	}
	ALBEDO = night_grade(color.rgb, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ALPHA = line * color.a;
}
