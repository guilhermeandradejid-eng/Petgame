// Perigo: faixa listrada preta e amarela de aviso de cais, sempre uma forma que se FECHA (telegrafia).
// modo 0: disco (o anel listrado cresce para dentro até fechar); modo 1: faixa de rota (enche até o fim, com setas).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
uniform vec3 amarelo : source_color = vec3(0.96, 0.75, 0.18);
uniform vec3 tinta : source_color = vec3(0.118, 0.102, 0.133);
uniform int modo = 0;
uniform float progresso = 0.0;   // 0..1
uniform float tam = 1.0;         // listras por unidade de UV
uniform float rolagem = 0.0;     // v2: as listras andam (em degrau, pelo tempo de simulação): perigo vivo, não decoração
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (modo == 0) {
		float r = length(p);
		// listras em espiral que giram para dentro
		float ang = atan(p.y, p.x) / 6.2832;
		float listra = step(0.5, fract(ang * 14.0 + r * tam * 2.4 - rolagem));
		vec3 c = mix(amarelo, tinta, listra);
		float borda = step(abs(r - 0.95), 0.05);
		float faixa = step(r, 0.95) * step(0.95 - mix(0.14, 0.95, progresso), r);
		if (max(borda, faixa) < 0.5) discard;
		ALBEDO = mix(c, tinta, borda);
	} else {
		float u = UV.x;
		float borda = step(0.82, abs(p.y));
		float faixa = step(u, progresso);
		// listras na diagonal, com largura em metros (tam), e setas de tinta indicando a rota
		float listra = step(0.5, fract(u * tam * 9.0 + p.y * 0.35 - rolagem));
		vec3 c = mix(amarelo, tinta, listra);
		// setas de creme recortadas apontando a rota, andando junto com as listras
		float sx = fract(u * 4.0 - rolagem * 0.25);
		float seta = step(abs(sx - 0.5 + abs(p.y) * 0.22), 0.07) * step(abs(p.y), 0.62);
		// ponta da faixa: a frente do enchimento tem borda de tinta grossa (lê como avanço)
		float frente = step(progresso - 0.025, u) * step(u, progresso);
		if (max(borda, faixa) < 0.5) discard;
		c = mix(c, vec3(0.93, 0.88, 0.78), seta * faixa);
		ALBEDO = mix(c, tinta, max(borda, frente));
	}
}
