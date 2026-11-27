// Bambinela e empanada: lona listrada remendada, com pregas (vértice) e barra em festão (recorte).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 rep = vec2(2.0, 1.0);
uniform float festao = 1.0;   // 1 = festão na borda de baixo, -1 = em cima
uniform float n_festao = 12.0;
uniform float pregas = 0.06;
uniform vec3 tinta : source_color = vec3(0.114, 0.094, 0.125);
uniform float sombra = 0.72;
uniform float brilho = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
varying float fold;
void vertex() {
	fold = sin(UV.x * 6.2831 * n_festao * 0.5);
	VERTEX.z += fold * pregas;
}
void fragment() {
	vec2 uv = UV;
	float y = festao > 0.0 ? uv.y : 1.0 - uv.y;
	float x = fract(uv.x * n_festao);
	float sc = 0.86 + 0.14 * sqrt(max(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)));
	if (y > sc) discard;
	vec3 c = texture(tex, uv * rep).rgb;
	// sombra das pregas em 2 degraus
	c *= mix(sombra, 1.0, step(-0.35, fold));
	// barra escura e contorno do festão
	c = mix(c, tinta, step(sc - 0.025, y));
	c = mix(c, c * 0.75, step(sc - 0.09, y) * step(y, sc - 0.025));
	ALBEDO = c * brilho * tint;
}
