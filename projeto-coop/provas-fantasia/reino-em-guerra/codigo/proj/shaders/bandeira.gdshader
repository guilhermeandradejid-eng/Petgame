// Bandeira do Porta-Estandarte: pano com vento (ondas que correm do mastro para a ponta), arrasto de mola vindo do
// script (follow-through) e o brasão do jogador 1 (torre) em papel reservado. Mesma gravura dos bonecos.
shader_type spatial;
render_mode skip_vertex_transform, specular_disabled, cull_disabled;
#include "res://shaders/grav.gdshaderinc"
uniform vec3 cor : source_color = vec3(0.850, 0.280, 0.170);
uniform float abre = 1.0;
uniform vec3 arrasto = vec3(0.0);
uniform float ondas = 1.0;          // 0: a malha já vem do pano simulado (verlet) em coordenadas de mundo
varying vec2 v_uv;
void vertex() {
	// malha no plano local XY, presa ao mastro em x = 0, estendida para -x. O script gira o nó para o vento.
	vec2 uv = UV;
	v_uv = uv;
	float u = uv.x;
	float tq = floor(tempo * 30.0) / 30.0;
	vec3 p = VERTEX;
	p.x *= mix(0.25, 1.0, abre);
	p.y -= (1.0 - abre) * 0.35 * u * u;
	p.z += (sin(u * 9.0 - tq * 11.0) * 0.06 * u + sin(u * 17.0 - tq * 17.0 + uv.y * 3.0) * 0.02 * u) * ondas;
	vec3 w = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	w += arrasto * u * u * 0.6;
	w.y -= curva(w);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = ondas > 0.5 ? normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz) : normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	ALBEDO = vec3(1.0);
	if (v_uv.x > 0.8 && abs(v_uv.y - 0.5) < (v_uv.x - 0.8) / 0.2 * 0.42) discard;   // rabo de andorinha
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// brasão: torre de papel no meio
	vec2 c = v_uv - vec2(0.36, 0.48);
	float torre = step(abs(c.x), 0.1) * step(abs(c.y + 0.04), 0.16);
	torre = max(torre, step(abs(c.x), 0.13) * step(abs(c.y + 0.22), 0.05) * step(0.5, fract(c.x * 11.0 + 0.5)));
	vec3 col = mix(cor_u(cor), PAPEL_DIA, torre);
	GRAV_SET(wp, v_uv * vec2(0.62, 0.42), vec4(col, 1.0), 4.4, 0.0);
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 n = NORMAL;
		if (dot(n, VIEW) < 0.0) n = -n;
		DIFFUSE_LIGHT += grav_cor(n, LIGHT, VIEW, ATTENUATION, GRAV_GET);
	}
}
