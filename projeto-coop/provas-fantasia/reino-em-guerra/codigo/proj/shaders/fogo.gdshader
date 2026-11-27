// Línguas de fogo (breu em chamas, fogueiras): cartão virado para a câmera com a forma de chama em gota, contorno de
// tinta, corpo laranja-mínio e miolo de papel-cera; a forma troca a cada 3 quadros (desenho animado em 2s/3s).
shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float tempo;
global uniform vec2 vento;
uniform vec3 cor : source_color = vec3(0.886, 0.404, 0.169);
uniform vec3 miolo : source_color = vec3(0.949, 0.902, 0.761);
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform float vida = 1.0;
uniform float brilho = 1.0;
varying float v_sd;
float h11(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_sd = h11(o.x * 13.1 + o.z * 7.7);
	vec3 cam_r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	float sx = length(MODEL_MATRIX[0].xyz); float sy = length(MODEL_MATRIX[1].xyz);
	vec3 w = o + cam_r * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy;
	float tq = floor(tempo * 20.0);
	w.xz += vento * 0.25 * max(VERTEX.y + 0.5, 0.0) * sy * (0.7 + 0.5 * h11(tq + v_sd * 50.0));
	float d = dot(w.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	w.y -= curva_k * e * e;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
}
float chama(vec2 p, float s) {
	// gota invertida com 2 ou 3 pontas que oscilam
	float y = p.y;                // 0 base .. 1 topo
	// gota: pé largo e redondo, corpo que afina em língua no alto
	float larg = 0.44 * pow(max(1.0 - y, 0.0), 0.8) * (0.72 + 0.28 * smoothstep(0.0, 0.2, y)) * smoothstep(-0.06, 0.05, y);
	float tq = floor(tempo * 20.0);
	float ond = sin(y * 7.0 + h11(tq + s * 31.0) * 6.28) * 0.08 * y;
	float lingua = 0.06 * sin(p.x * 18.0 + s * 9.0 + tq) * y * y;
	return larg - abs(p.x - ond) + lingua;
}
void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	p.y /= max(vida, 0.05);
	float d = chama(p, v_sd);
	if (d < 0.0 || p.y > 1.0) discard;
	float dm = chama(vec2(p.x * 1.9, p.y * 1.5 + 0.05), v_sd + 0.5);
	vec3 c = cor * brilho;
	if (dm > 0.0) c = miolo * brilho;
	if (d < 0.035) c = tinta;
	ALBEDO = c;
}
