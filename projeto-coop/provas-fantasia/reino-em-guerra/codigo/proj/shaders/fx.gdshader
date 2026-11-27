// Efeitos chapados (sem luz): raio de papel rasgado (miolo branco-papel, borda azul), cera, faíscas, anéis, tinta.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
uniform vec3 cor : source_color = vec3(0.957, 0.945, 0.910);
uniform vec3 cor_borda : source_color = vec3(0.498, 0.639, 0.878);
uniform float brilho = 1.0;
uniform int modo = 0;      // 0 chapado, 1 fita com borda (UV.x atravessa), 2 anel, 3 raio: miolo branco, fio azul, halo de tinta
uniform vec3 cor_halo : source_color = vec3(0.137, 0.110, 0.090);
uniform float alfa_corte = 0.0;
uniform float curvar = 1.0;
void vertex() {
	if (curvar > 0.5) {
		float d = dot(VERTEX.xz - foco.xz, curva_dir);   // tronco que rola: o chão cai para o norte, o horizonte fica reto
		float e = max(d - curva_r0, 0.0);
		VERTEX.y -= curva_k * e * e;
	}
}
void fragment() {
	vec3 c = cor;
	if (modo == 1) {
		float b = abs(UV.x - 0.5) * 2.0;
		c = mix(cor, cor_borda, step(0.72, b));
	}
	float br = brilho;
	if (modo == 3) {
		float b = abs(UV.x - 0.5) * 2.0;
		c = b < 0.34 ? cor : (b < 0.5 ? cor_borda : cor_halo / max(brilho, 0.01));
	}
	if (COLOR.a < alfa_corte) discard;
	ALBEDO = c * br;
}
