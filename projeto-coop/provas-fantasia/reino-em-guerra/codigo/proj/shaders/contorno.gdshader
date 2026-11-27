// Contorno por casca invertida (gerada no Blender; alfa da cor = peso). Largura constante em pixels e 2x mais grossa
// no lado oposto à luz, como o gravador faz para dar volume. Pressão de ±12% por vértice (linha de mão).
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_front, shadows_disabled, fog_disabled;
global uniform vec3 sol_dir;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
uniform float px_1080 = 1.5;
uniform vec3 ink_col : source_color = vec3(0.137, 0.110, 0.090);
uniform float clarao = 0.0;
uniform vec3 cera_col : source_color = vec3(0.949, 0.902, 0.761);
uniform float isolado = 0.0;        // contorno branco-cera por fora (unção)
uniform float esconde = 0.0;
uniform float curvar = 1.0;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	vec3 w = VERTEX;
	float d = dot(w.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	w.y -= curva_k * e * e * curvar;
	vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
	vec3 nv = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool orto = PROJECTION_MATRIX[3][3] > 0.5;
	float span = orto ? abs(2.0 / PROJECTION_MATRIX[1][1]) : abs((-vp.z) * 2.0 / PROJECTION_MATRIX[1][1]);
	float lado = smoothstep(-0.25, 0.45, -dot(normalize(NORMAL), normalize(sol_dir)));
	float wid = px_1080 / 1080.0 * span * (1.0 + lado) * (0.88 + 0.24 * h(floor(VERTEX * 40.0)));
	wid *= COLOR.a * (1.0 + isolado * 1.6) * (1.0 - esconde);
	vp.xyz += nv * wid;
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	vec3 c = mix(ink_col, cera_col, isolado);
	ALBEDO = mix(c, vec3(0.91, 0.89, 0.81), clarao);
}
