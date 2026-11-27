// Brilho pintado em cartão aditivo virado para a câmera: halo de lanterna, do Sino, do acampamento rival.
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, cull_disabled, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(1.0, 0.7, 0.3);
uniform float forca = 1.0;
uniform float nucleo = 0.6;
uniform float billboard = 1.0;
varying vec3 wp;
void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	wp = c;
	if (billboard > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		vec3 v = c + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + INV_VIEW_MATRIX[1].xyz * VERTEX.y * s;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
	} else {
		wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float k = smoothstep(1.0, 0.0, d);
	k = k * k * 0.6 + smoothstep(0.25, 0.0, d) * nucleo;
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(cor * k * forca * (1.0 - f.a * 0.55));
}
