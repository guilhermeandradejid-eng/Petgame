// Casca invertida gerada no Blender (alfa da cor de vértice = peso). Espessura constante em pixels de tela,
// proporcional à altura da imagem (2,7 px em 1080p), com variação de pressão de ±15%.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;
uniform float px_1080 = 2.4;
uniform vec3 ink_col : source_color = vec3(0.114, 0.094, 0.125);
uniform float flash = 0.0;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	float span = abs(ortho ? 2.0 / PROJECTION_MATRIX[1][1] : (-vp.z) * 2.0 / PROJECTION_MATRIX[1][1]);
	float wid = px_1080 / 1080.0 * span;
	float press = 0.85 + 0.3 * h(floor(VERTEX * 30.0));
	vp.xyz += nv * (wid * 1.0 * press);
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() { ALBEDO = mix(ink_col, vec3(0.95, 0.9, 0.85), flash); }
