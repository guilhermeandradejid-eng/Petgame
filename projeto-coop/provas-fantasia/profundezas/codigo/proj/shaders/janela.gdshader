// Janela acesa do povoado distante (e do Dente): retângulo quente com caixilho em cruz, virado para a câmera.
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, cull_disabled, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform float forca = 1.0;
uniform vec3 cor : source_color = vec3(1.0, 0.62, 0.26);
varying vec3 wp;
varying float rnd;
void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	wp = c;
	rnd = fract(sin(dot(c.xz, vec2(12.9898, 78.233))) * 43758.5);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 v = c + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + vec3(0.0, 1.0, 0.0) * VERTEX.y * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float vidro = step(max(p.x, p.y), 0.72);
	float caixilho = step(abs(UV.x - 0.5), 0.06) + step(abs(UV.y - 0.45), 0.05);
	float halo = smoothstep(1.0, 0.7, max(p.x, p.y)) * 0.25;
	float k = max(vidro * (1.0 - min(caixilho, 1.0) * 0.8), halo) * (0.6 + 0.6 * rnd);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(cor * k * forca * (1.0 - f.a * 0.5));
}
