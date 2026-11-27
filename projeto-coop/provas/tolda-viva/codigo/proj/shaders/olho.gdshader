// Olho pintado: amêndoa branca, íris/pupila escura com ponto de brilho, pálpebra na cor da madeira.
// Controlado por abertura (0 fechado .. 1 aberto) e pupila (desvio). Nítido em qualquer resolução.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform float abertura = 1.0;
uniform vec2 pupila = vec2(0.0, 0.0);
uniform float tam_pupila = 0.42;
uniform vec3 branco : source_color = vec3(0.95, 0.91, 0.82);
uniform vec3 tinta : source_color = vec3(0.114, 0.094, 0.125);
uniform float sombra = 0.0;
void fragment() {
	vec3 lid = COLOR.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	lid = mix(lid * 12.92, 1.055 * pow(lid, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), lid));
#endif
	vec2 p = UV * 2.0 - 1.0;
	// amêndoa: interseção de dois círculos (canto externo mais pontudo)
	float top = 1.0 - pow(abs(p.x), 1.8);
	float bot = -(1.0 - pow(abs(p.x), 2.4)) * 0.8;
	float inside = step(bot, p.y) * step(p.y, top);
	float edge = 0.12;
	float outline = inside * (1.0 - step(bot + edge, p.y) * step(p.y, top - edge) * step(abs(p.x), 0.93));
	if (inside < 0.5) discard;
	// pálpebra: corta de cima para baixo
	float lid_y = mix(bot - 0.05, top + 0.05, abertura);
	float lidm = step(lid_y, p.y);
	vec2 pc = (p - pupila) * vec2(1.0, 1.1);
	float iris = step(length(pc), tam_pupila);
	float hl = step(length(pc - vec2(-0.12, 0.16)), tam_pupila * 0.33);
	vec3 col = branco;
	col = mix(col, tinta, iris);
	col = mix(col, branco, hl * iris);
	col = mix(col, tinta, outline);
	col = mix(col, lid * (1.0 - sombra * 0.3), lidm);
	// linha da pálpebra
	col = mix(col, tinta, step(abs(p.y - lid_y), 0.09) * step(abertura, 0.97));
	ALBEDO = col;
}
