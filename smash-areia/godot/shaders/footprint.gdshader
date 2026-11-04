// Pegadas e marcas na areia (MultiMesh). Os jogadores jogam descalços: a pegada
// tem calcanhar, planta do pé e cinco dedinhos. COLOR.r = 0 desenha só uma
// marca oval macia (mergulho, carrinho).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://shaders/lighting.gdshaderinc"

varying float alpha;
varying float foot;

void vertex() {
	alpha = COLOR.a;
	foot = COLOR.r;
}

float blob(vec2 p, vec2 c, vec2 r) {
	return smoothstep(1.0, 0.6, length((p - c) / r));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // y: -1 calcanhar ... +1 ponta
	float oval = smoothstep(1.0, 0.55, length(p * vec2(1.0, 0.75)));
	float m = oval;
	if (foot > 0.5) {
		float sole = max(blob(p, vec2(0.0, -0.5), vec2(0.5, 0.38)), blob(p, vec2(0.06, 0.12), vec2(0.62, 0.42)));
		sole = max(sole, blob(p, vec2(0.0, -0.18), vec2(0.42, 0.4)) * 0.85);
		float toes = blob(p, vec2(-0.3, 0.7), vec2(0.2, 0.17));
		toes = max(toes, blob(p, vec2(0.0, 0.78), vec2(0.14, 0.12)));
		toes = max(toes, blob(p, vec2(0.24, 0.74), vec2(0.13, 0.11)));
		toes = max(toes, blob(p, vec2(0.45, 0.64), vec2(0.11, 0.1)));
		toes = max(toes, blob(p, vec2(0.62, 0.49), vec2(0.1, 0.09)));
		m = max(sole, toes);
	}
	ALBEDO = night_grade(vec3(0.62, 0.44, 0.32), (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ALPHA = m * alpha * 0.5;
}
