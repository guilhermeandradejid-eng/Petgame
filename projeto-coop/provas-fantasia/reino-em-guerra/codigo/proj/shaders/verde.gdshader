// Verde-mordente reservado ao perigo: olhos dos mortos (acendem a menos de 12 m de um herói) e boca da Carpideira.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_back, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
uniform float aceso = 1.0;
uniform float clarao = 0.0;
void vertex() {
	float d = dot(VERTEX.xz - foco.xz, curva_dir);   // tronco que rola: o chão cai para o norte, o horizonte fica reto
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
}
void fragment() {
	vec3 apagado = vec3(0.0168, 0.0116, 0.0085);
	vec3 c = mix(apagado, COLOR.rgb * (1.0 + 0.6 * aceso), aceso);
	ALBEDO = mix(c, vec3(0.91, 0.89, 0.81), clarao);
}
