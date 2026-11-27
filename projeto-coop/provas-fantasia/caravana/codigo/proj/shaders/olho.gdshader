// Olho pintado (heróis) e olho de bicho da Treva (sempre branco, lê em qualquer luz). Quad com UV 0..1.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform int tipo = 0;              // 0 herói; 1 bicho da Treva (ponto -> fenda)
uniform float abertura = 1.0;      // pálpebra (1 aberto, 0 fechado)
uniform vec2 olhar = vec2(0.0);
uniform float fenda = 0.0;         // telegrafia do Fuligento: o ponto vira fenda
uniform float pupila = 0.5;
uniform vec3 tinta : source_color = vec3(0.09, 0.06, 0.08);
uniform vec3 branco : source_color = vec3(0.96, 0.93, 0.85);
uniform vec3 iris : source_color = vec3(0.32, 0.2, 0.12);
uniform float brilho = 1.0;
void vertex() { VERTEX.y -= drop_curva(VERTEX); }
void fragment() {
	vec3 tinta_l = entrada(tinta);
	vec3 branco_l = entrada(branco);
	vec3 iris_l = entrada(iris);
	vec2 p = UV * 2.0 - 1.0;
	if (tipo == 0) {
		// olho de botão de fuligem: disco escuro, aro talhado, um brilho pequeno e duro; pálpebra de cera
		float d0 = length(p * vec2(1.0, 0.92));
		if (d0 > 0.97) discard;
		float lid = mix(-1.05, 1.0, abertura);
		vec2 q = p - olhar * 0.22;
		vec3 c = vec3(0.02, 0.015, 0.018);
		c = mix(c, vec3(0.06, 0.045, 0.04), step(0.78, d0));            // aro talhado
		c = mix(c, vec3(0.05, 0.04, 0.045), (1.0 - smoothstep(0.5, 0.56, length(q))) * step(0.42, length(q)) * 0.6);   // furo do botão
		c = mix(c, branco_l * 1.1, step(length(q - vec2(-0.28, 0.32)), 0.15 * brilho));
		if (p.y > lid) c = vec3(-1.0);
		if (abs(p.y - lid) < 0.16 && d0 < 0.97) c = vec3(0.55, 0.42, 0.33);
		if (c.r < 0.0) discard;
		ALBEDO = c;
	} else {
		// olho de bicho da Treva: buraco de pavio queimado (borda carbonizada) com uma brasa em fenda dentro;
		// na telegrafia a fenda fecha e a brasa esquenta
		float k = mix(0.42, 0.16, fenda);
		vec2 q = p - olhar * 0.25;
		float buraco = length(p * vec2(1.0, 0.85));
		if (buraco > 0.98) discard;
		float fd = length(q * vec2(1.0 / 0.75, 1.0 / k));
		vec3 c = vec3(0.012, 0.008, 0.01);
		c = mix(c, vec3(0.08, 0.05, 0.04), step(0.8, buraco));
		vec3 brasa = mix(vec3(1.6, 0.35, 0.06), vec3(2.4, 1.5, 0.6), 1.0 - smoothstep(0.0, 0.7, fd));
		c = mix(c, brasa * brilho * mix(1.0, 1.4, fenda), 1.0 - step(1.0, fd));
		ALBEDO = c;
	}
	ALBEDO = saida(ALBEDO);
}
