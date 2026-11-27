// Fungo de resina translúcida: mais claro por dentro que por fora, lamelas acesas por baixo, saturação do ciano
// limitada a 56%. Acende com a frente da Respiração (resp.y = raio da frente a partir de resp.zw).
shader_type spatial;
render_mode unshaded, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float energia = 1.0;
uniform float base_acesa = 0.55;
uniform float pintura_k = 1.0;
uniform float nevoa_k = 0.8;
uniform float dessat = 0.0;        // v2: o ciano pleno é da magia; os fungos ficam 30 a 40% menos saturados
varying vec3 wp;
varying vec3 wn;
varying float inst;
void vertex() {
	wp = VERTEX; wn = NORMAL;
	inst = fract(sin(dot(NODE_POSITION_WORLD.xz + MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5);
}
void fragment() {
	vec3 n = normalize(wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 c = vc(COLOR.rgb);
	c = mix(c, vec3(luma(c)), dessat);
	float fr = 1.0 - clamp(dot(n, V), 0.0, 1.0);
	// resina translúcida: casca escura e fosca em cima, luz presa por dentro que vaza pela borda e pelas lamelas
	float dentro = smoothstep(0.25, 0.95, fr) + smoothstep(0.1, -0.6, n.y) * 1.2;
	vec3 casca = c * 0.42 * (0.85 + 0.3 * smoothstep(0.3, 0.95, n.y));
	vec3 luz = mix(c, vec3(0.75, 0.95, 0.92), 0.25) * 1.35;
	// frente da Respiração: fungos acendem quando ela passa (cada um com um pequeno atraso)
	float dfront = length(wp.xz - resp.zw);
	float lit = smoothstep(0.0, 6.0, resp.y - dfront - inst * 4.0);
	float e = energia * mix(base_acesa, 1.0, lit);
	vec3 col = mix(casca, luz * e, clamp(dentro * e, 0.0, 1.0));
	// pintas claras (luz pintada) e veios
	col += luz * 0.25 * e * smoothstep(0.6, 0.75, vnoise(wp.xz * 3.0 + wp.y)) * step(0.3, n.y);
	col = pocas(col, wp, 0.6);
	col = clarao(col, wp, n);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(col, f.rgb, f.a * nevoa_k));
}
