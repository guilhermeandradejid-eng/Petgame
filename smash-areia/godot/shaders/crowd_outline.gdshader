// Contorno fino da torcida (casco invertido) com a mesma animação do corpo.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
#include "res://shaders/lighting.gdshaderinc"
#include "res://shaders/crowd_anim.gdshaderinc"

uniform vec4 color : source_color = vec4(0.227, 0.165, 0.29, 1.0);   // #3A2A4A
uniform float width = 0.012;

void vertex() {
	VERTEX = crowd_anim(VERTEX, UV, INSTANCE_CUSTOM, MODEL_MATRIX, TIME);
	VERTEX += normalize(NORMAL) * width;
}

void fragment() {
	ALBEDO = night_grade(color.rgb, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
