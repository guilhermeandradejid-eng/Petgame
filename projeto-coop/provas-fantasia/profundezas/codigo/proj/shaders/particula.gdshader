// Partículas em MultiMesh (billboard), deterministas por quadro: 0 chuva (risco, acende na Coluna e no clarão),
// 1 esporo (ponto que sobe), 2 brasa/faísca, 3 folha de fungo (dourada na Coluna), 4 gesso/pó, 5 faísca do Enxame,
// 6 nuvem de esporos (bolha macia), 7 resina (gota âmbar), 8 fumaça do turíbulo.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform int tipo = 0;
uniform vec3 cor : source_color = vec3(1.0);
uniform float forca = 1.0;
uniform vec3 coluna = vec3(6.0, 0.0, -118.0);
uniform float coluna_r = 11.0;
varying vec3 wp;
varying float rnd;
void vertex() {
	rnd = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	vec3 c = MODEL_MATRIX[3].xyz;
	wp = c;
	float sx = length(MODEL_MATRIX[0].xyz), sy = length(MODEL_MATRIX[1].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	if (tipo == 0) {
		// risco de chuva: alinhado à queda (quase vertical na tela)
		vec3 dir = normalize(vec3(vento.x * 0.15, -1.0, vento.y * 0.15));
		vec3 sd = normalize(cross(dir, normalize(CAMERA_POSITION_WORLD - c)));
		VERTEX = c + sd * VERTEX.x * sx + dir * -VERTEX.y * sy;
	} else {
		VERTEX = c + right * VERTEX.x * sx + up * VERTEX.y * sy;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(VERTEX, 1.0);
}
// v2, bíblia de VFX: toda partícula é uma forma recortada (sem alfa gaussiano) em 2 ou 3 tons chapados, com
// uma beirada mais escura do próprio tom, como a casca dos personagens.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	vec3 c = cor;
	float a = 1.0;
	float naCol = 1.0 - smoothstep(coluna_r * 0.6, coluna_r, length(wp.xz - coluna.xz));
	if (tipo == 0) {
		// gota riscada: fio recortado com a cabeça mais clara
		a = step(abs(p.x), 0.55) * step(abs(p.y), 0.92);
		float cab = step(p.y, -0.55);
		c = mix(vec3(0.5, 0.58, 0.66), vec3(0.85, 0.92, 1.0), cab);
		c = mix(c, vec3(1.0, 0.85, 0.5) * 1.5, naCol);
		a *= mix(mix(0.38, 0.75, cab), 0.9, naCol);
	} else if (tipo == 1) {
		a = step(d, 0.85);
		c = mix(cor * 1.1, cor * 0.62, step(0.58, d)) * (1.0 + naCol);
	} else if (tipo == 2 || tipo == 5) {
		a = step(d, 0.95);
		c = mix(vec3(0.95, 1.0, 1.0), cor * 1.15, step(0.38, d));
		c = mix(c, cor * 0.38, step(0.76, d));
	} else if (tipo == 3) {
		float leaf = step(length(p * vec2(1.0, 2.2)), 0.9);
		a = leaf;
		c = mix(cor, vec3(1.0, 0.82, 0.45) * 1.4, naCol);
	} else if (tipo == 4) {
		a = step(d, 0.9);
		c = mix(cor * (0.85 + 0.3 * rnd), cor * 0.5, step(0.66, d));
	} else if (tipo == 6 || tipo == 8) {
		// bolha cel: corpo, luz de cima recortada e beirada escura
		a = step(d, 0.92) * (tipo == 6 ? 0.88 : 0.55);
		float luz = step(length(p - vec2(-0.18, 0.22)), 0.5);
		c = mix(cor, cor * 1.28 + 0.03, luz);
		c = mix(c, cor * 0.55, step(0.76, d));
	} else if (tipo == 7) {
		a = step(d, 0.95);
		c = cor * (1.0 + 0.5 * step(length(p - vec2(-0.3, 0.3)), 0.35));
		c = mix(c, cor * 0.5, step(0.78, d));
	}
	a *= forca;
	if (a < 0.01) discard;
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a));
	ALPHA = clamp(a, 0.0, 1.0);
}
