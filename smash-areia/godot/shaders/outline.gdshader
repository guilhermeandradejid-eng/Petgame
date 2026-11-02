// Contorno preto "inverted hull": a malha é inflada e desenhada de costas.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.07, 0.04, 0.12, 1.0);
uniform float width = 0.022;
uniform float max_scale = 2.6;

void vertex() {
	// o traço engrossa com a distância para não sumir nos jogadores e na bola do fundo
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += normalize(NORMAL) * width * clamp(d / 8.0, 1.0, max_scale);
}

void fragment() {
	ALBEDO = color.rgb;
}
