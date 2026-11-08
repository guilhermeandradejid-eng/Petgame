shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_back, blend_mix, shadows_disabled, fog_disabled;
// Silhueta do carro quando algo (outro trecho de pista, ponte) está NA FRENTE dele.
// O teste de profundidade é invertido: só desenha onde o carro está escondido. O vértice é "puxado"
// para a câmera (push), então peças do próprio carro e a mureta ao lado não acionam o efeito.
uniform vec4 col : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float strength = 0.6;
uniform float push = 3.0;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += push;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	float rim = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float scan = 0.85 + 0.15 * sin(FRAGCOORD.y * 0.9 + TIME * 6.0);
	ALBEDO = col.rgb * (0.7 + rim * 1.6) * scan;
	ALPHA = clamp((0.28 + rim * 0.6) * strength, 0.0, 1.0);
}
