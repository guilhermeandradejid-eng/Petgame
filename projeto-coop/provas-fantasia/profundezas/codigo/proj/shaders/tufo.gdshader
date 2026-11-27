// Musgo e grama estática de maquete (MultiMesh): cor de vértice, ponta mais clara, balança no vento da Respiração.
// Na Expira o bafo morno empurra para cima e para fora (resp.x > 0).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float vento_k = 1.0;
uniform float altura = 0.1;
varying vec3 wp;
varying float hh;
void vertex() {
	vec3 o = NODE_POSITION_WORLD;
	o = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y - o.y, 0.0);
	hh = clamp(h / altura, 0.0, 1.0);
	float ph = dot(o.xz, vec2(0.37, 0.21));
	float g = sin(vento.w * 2.1 + ph) * 0.6 + sin(vento.w * 3.3 + ph * 1.7) * 0.4;
	// frente da Respiração: depois que passa, a grama vira para cima e para longe da frente
	float dfront = length(o.xz - resp.zw);
	float pass = smoothstep(0.0, 4.0, resp.y - dfront);
	vec2 away = normalize(o.xz - resp.zw + vec2(0.001));
	vec2 push = vento.xy * (vento.z + g * 0.4) * 0.6 + away * pass * 0.9 * resp.x;
	VERTEX.xz += push * hh * hh * altura * vento_k;
	VERTEX.y += pass * hh * altura * 0.25 * resp.x;
	wp = VERTEX;
}
void fragment() {
	vec3 c = vc(COLOR.rgb) * mix(0.65, 1.3, hh);
	c = pocas(c, wp, 1.0);
	c = clarao(c, wp, vec3(0, 1, 0));
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a));
}
