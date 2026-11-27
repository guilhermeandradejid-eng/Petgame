// Feixe pálido (Farol Cego) ou cone falso de luz: aditivo, some nas pontas, com poeira pintada.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(0.55, 0.62, 0.7);
uniform float forca = 0.35;
uniform float curva = 1.0;
varying vec3 vw;
void vertex() { if (curva > 0.5) VERTEX.y -= drop_curva(VERTEX); vw = VERTEX; }
void fragment() {
	vec3 cor_l = entrada(cor);
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = UV.y;
	float n = vnoise(vec2(UV.x * 8.0, UV.y * 3.0 - vento.w * 0.2));
	float a = smoothstep(0.0, 0.5, edge) * smoothstep(0.0, 0.1, along) * (1.0 - smoothstep(0.5, 1.0, along)) * (0.7 + 0.3 * n);
	ALBEDO = cor_l * a * forca;
	ALBEDO = saida(ALBEDO);
}
