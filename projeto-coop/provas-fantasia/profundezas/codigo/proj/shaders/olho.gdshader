// Olho pintado de miniatura (heróis): branco de osso, íris, pupila, ponto de luz pintado e pálpebra. Quad com UV 0..1.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform int tipo = 0;              // 0 herói; 1 bicho da Treva (ponto -> fenda)
uniform float abertura = 1.0;      // pálpebra (1 aberto, 0 fechado)
uniform vec2 olhar = vec2(0.0);
uniform float fenda = 0.0;         // telegrafia do Fuligento: o ponto vira fenda
uniform float pupila = 0.56;
uniform vec3 tinta : source_color = vec3(0.09, 0.06, 0.08);
uniform vec3 branco : source_color = vec3(0.8, 0.75, 0.66);
uniform vec3 iris : source_color = vec3(0.32, 0.2, 0.12);
uniform float brilho = 1.0;
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (tipo == 0) {
		float d0 = length(p * vec2(1.0, 0.9));
		if (d0 > 0.97) discard;
		float lid = mix(-1.05, 1.0, abertura);
		vec2 q = p - olhar * 0.3 - vec2(0.0, -0.05);
		vec3 c = branco;
		c = mix(c, iris, step(length(q * vec2(1.0, 0.85)), pupila + 0.12));
		c = mix(c, tinta, step(length(q * vec2(1.0, 0.85)), pupila));
		c = mix(c, vec3(0.95, 0.92, 0.85), step(length(q - vec2(-0.17, 0.2)), 0.11));
		// olho em cavidade: sombra da pálpebra e da órbita sobre o terço de cima
		c *= mix(1.0, 0.55, smoothstep(lid - 0.75, lid - 0.1, p.y));
		c = mix(c, tinta, step(0.8, d0));
		// pálpebra de cima
		if (p.y > lid) c = vec3(-1.0);
		if (abs(p.y - lid) < 0.14 && d0 < 0.97) c = tinta;
		if (c.r < 0.0) discard;
		vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
		ALBEDO = saida(mix(c, f.rgb, f.a));
	} else {
		// olho de fuligem: ponto branco redondo que vira fenda; borda escura
		float k = mix(1.0, 0.18, fenda);
		vec2 q = p - olhar * 0.25;
		float d = length(q * vec2(1.0, 1.0 / k));
		if (d > 0.95) {
			if (length(p) > 0.98 || d > 1.25) discard;
			ALBEDO = saida(tinta); 
		} else {
			ALBEDO = saida(branco * brilho * 1.4);
		}
	}
}
