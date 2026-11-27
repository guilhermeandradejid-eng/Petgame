// Fita do passe: faixa na cor de quem lançou, com borda creme e verso mais escuro; some da cauda para a frente.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.17, 0.39, 0.84);
uniform vec3 verso : source_color = vec3(0.1, 0.2, 0.45);
uniform vec3 borda : source_color = vec3(0.93, 0.88, 0.78);
void fragment() {
	// UV.x: 0 cauda .. 1 cabeça; UV.y: 0..1 através
	vec3 c = FRONT_FACING ? cor : verso;
	float e = step(UV.y, 0.14) + step(0.86, UV.y);
	c = mix(c, borda, e);
	// recortes em dente na cauda (fita de papel cortada)
	float dente = abs(fract(UV.x * 7.0) - 0.5) * 2.0;
	if (UV.x < 0.35 && abs(UV.y - 0.5) * 2.0 > 1.0 - (0.35 - UV.x) * 2.6 * dente) discard;
	ALBEDO = c;
}
