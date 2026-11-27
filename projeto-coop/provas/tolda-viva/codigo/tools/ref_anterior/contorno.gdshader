// Casca invertida: geometria gerada no Blender (cor de vértice = tinta, alfa = peso do vertex group "contorno").
// Aqui só se acrescenta espessura constante em pixels de tela, com variação de "pressão" de ±20% (regra 5).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;
uniform float px_width = 1.4;
uniform vec3 ink_col : source_color = vec3(0.118, 0.102, 0.110);
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	float span = ortho ? 2.0 / PROJECTION_MATRIX[1][1] : (-vp.z) * 2.0 / PROJECTION_MATRIX[1][1];
	float mpp = span / VIEWPORT_SIZE.y;
	float press = 0.8 + 0.4 * h(floor(VERTEX * 40.0));
	vp.xyz += nv * px_width * COLOR.a * press * mpp;
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() { ALBEDO = ink_col; }
