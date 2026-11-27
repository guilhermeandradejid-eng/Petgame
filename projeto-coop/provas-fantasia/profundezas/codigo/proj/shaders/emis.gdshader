// Emissivo pintado: chama, geodo, brasas, isca do Bocalume, boca do Ouvidor. 'perigo' troca para o magenta reservado.
shader_type spatial;
render_mode unshaded, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float energia = 1.6;
uniform float acende = 1.0;       // 0 apagado (isca na telegrafia)
uniform float perigo = 0.0;       // 0..1 -> magenta
uniform vec3 magenta : source_color = vec3(0.941, 0.235, 0.62);
uniform vec3 apagado : source_color = vec3(0.12, 0.1, 0.12);
uniform float pisca = 0.0;
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	vec3 c = vc(COLOR.rgb);
	float e = energia * acende;
	float boca = step(luma(c), 0.12);      // a boca (cor escura) é o ponto que acende em magenta
	vec3 o = mix(apagado * (0.6 + 0.4 * c), c * e, clamp(acende, 0.0, 1.0));
	vec3 ob = mix(c * 2.5 + vec3(0.05, 0.03, 0.06), magenta * (1.6 + pisca), perigo);
	o = mix(o, ob, boca);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(o, f.rgb, f.a * 0.7));
}
