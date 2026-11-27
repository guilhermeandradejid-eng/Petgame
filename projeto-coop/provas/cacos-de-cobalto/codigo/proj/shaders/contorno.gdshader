// Casca invertida (gerada no Blender, alfa da cor de vértice = peso do contorno).
// Espessura constante em pixels de tela: px_1080 a 1080 linhas, escala com a altura da imagem.
// Pressão do traço ±20% por hash do vértice (regra 5 do contrato anti-slop).
// Obs. (4.7.2, testado): escrever POSITION não deslocou a casca, e a conta com PROJECTION_MATRIX
// e VIEWPORT_SIZE no vertex() zerava o deslocamento; a câmera passa metros por pixel por uniform.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;
uniform float px_1080 = 2.75;
uniform float vh = 1080.0;        // altura da imagem em px
uniform float k_persp = 0.0005;   // 2*tan(fov/2)/vh (perspectiva)
uniform float mpp_ortho = 0.0;    // metros por px (ortográfica); 0 = perspectiva
uniform vec3 ink_col : source_color = vec3(0.051, 0.063, 0.161);
uniform float invert = 0.0;
uniform vec3 neg_ink : source_color = vec3(0.953, 0.776, 0.192);
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float mpp = mpp_ortho > 0.0 ? mpp_ortho : max(0.1, -vp.z) * k_persp;
	float press = 0.8 + 0.4 * h(floor(VERTEX * 40.0));
	float px = px_1080 * vh / 1080.0;
	VERTEX += NORMAL * px * COLOR.a * press * mpp;
}
void fragment() { ALBEDO = mix(ink_col, neg_ink, invert); }
