// Estrela de impacto pintada (billboard): estrela de 8 pontas como as dos painéis de azulejo,
// em 3 valores (núcleo claro, corpo na cor da matéria, contorno azul-noite), pontas irregulares.
// Abre ao longo da vida ("a ajuda cresce"); quadros desenhados a 30 por segundo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform vec3 col : source_color = vec3(0.953, 0.776, 0.192);
uniform vec3 core : source_color = vec3(1.0, 0.98, 0.88);
uniform vec3 edge : source_color = vec3(0.114, 0.153, 0.333);
uniform float life = 0.3;        // 0..1
uniform float points = 8.0;
uniform float seed = 0.0;
uniform float emit = 2.0;
float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + seed;
	float k = floor((a / 6.2831 + 0.5) * points);
	float fa = fract((a / 6.2831 + 0.5) * points);
	float len = 0.55 + 0.45 * hash(k + seed * 7.0);
	float spike = mix(0.22, len, pow(1.0 - abs(fa - 0.5) * 2.0, 2.2));
	float grow = smoothstep(0.0, 0.25, life);
	float R = spike * grow * (1.0 - 0.35 * smoothstep(0.6, 1.0, life));
	float hole = smoothstep(0.55, 1.0, life) * R * 0.8;  // fim: a estrela se abre por dentro e some
	float body = step(r, R) * step(hole, r);
	float rim = step(r, R + 0.07) * step(max(hole - 0.07, 0.0), r);
	float cor = step(r, R * 0.42) * step(hole, r);
	vec3 c = mix(edge, col, body);
	c = mix(c, core, cor);
	float al = max(rim, body);
	if (al < 0.5) discard;
	ALBEDO = c;
	EMISSION = (col * body + core * cor) * emit;
}
