// Contorno preto "inverted hull": a malha é inflada e desenhada de costas.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.07, 0.04, 0.12, 1.0);
uniform float width = 0.022;

void vertex() {
	VERTEX += normalize(NORMAL) * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
