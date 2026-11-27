// Brilho próprio: vidro da lanterna, chama do chapéu-vela. Igual na luz e na Treva. HDR > 1 para o glow do PC.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float energia = 2.2;
uniform float chama = 0.0;   // 1: tremula em degraus (12 fps)
uniform float apagada = 0.0;
void vertex() {
	if (chama > 0.5) {
		float st = floor(TIME * 12.0);
		float h = VERTEX.y - NODE_POSITION_WORLD.y;
		VERTEX.x += (h31(vec3(st, 1.0, 2.0)) - 0.5) * 0.02 * h * 6.0;
		VERTEX.z += (h31(vec3(st, 5.0, 3.0)) - 0.5) * 0.02 * h * 6.0;
	}
	VERTEX.y -= drop_curva(VERTEX);
}
void fragment() {
	vec3 c = COLOR.rgb * energia;
	ALBEDO = mix(c, COLOR.rgb * 0.15, apagada);
	ALBEDO = saida(ALBEDO);
}
