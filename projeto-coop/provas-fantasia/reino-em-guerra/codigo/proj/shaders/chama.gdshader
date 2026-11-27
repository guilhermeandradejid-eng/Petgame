// Chama de vela e de tocha: laranja-mínio com miolo de papel, inclinada pelo vento, tremendo em degraus de 2 quadros.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float tempo;
global uniform vec2 vento;
uniform float brilho = 1.0;
uniform float apaga = 0.0;
varying float v_h;
void vertex() {
	float d = dot(VERTEX.xz - foco.xz, curva_dir);   // tronco que rola: o chão cai para o norte, o horizonte fica reto
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tq = floor(tempo * 30.0) / 30.0;
	float k = clamp(COLOR.a, 0.0, 1.0);
	v_h = fract(VERTEX.y * 30.0);
	VERTEX.xz += vento * 0.012 * (1.0 + 0.5 * sin(tq * 23.0 + VERTEX.x * 40.0));
	VERTEX *= 1.0;
}
void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c * (1.0 + 0.6 * brilho), vec3(0.98, 0.9, 0.7) * (1.0 + 0.8 * brilho), 0.3) * (1.0 - apaga);
	if (apaga > 0.99) discard;
}
