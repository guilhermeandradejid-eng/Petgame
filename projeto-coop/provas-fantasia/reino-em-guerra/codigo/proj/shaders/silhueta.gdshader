// Silhuetas de fundo (colinas, Prensa, Campanário, fumaça distante): perspectiva atmosférica de gravura. Cada plano
// mais longe tem menos tinta (grão de aquatinta mais ralo) e linha de crista mais fina; o pé de cada plano se
// desfaz em névoa (papel). Sem hachura: a linha só existe perto.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform sampler2D grao : filter_nearest, repeat_enable;
global uniform vec4 papel_frio : source_color;
global uniform vec4 papel_quente : source_color;
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform float tom = 0.5;        // cobertura de tinta no alto do plano
uniform float pe = 0.0;         // cobertura no pé (névoa)
uniform float x_quente = 0.6;   // onde, na tela, o papel passa de frio a quente
void fragment() {
	float v = clamp(UV.y, 0.0, 1.0);   // 0 no pé (névoa), 1 na crista
	float cob = mix(pe, tom, smoothstep(0.0, 1.0, v));
	vec4 G = texture(grao, FRAGCOORD.xy / 256.0);
	float g = G.r * 0.996 + 0.002;
	vec3 papel = fract(G.r + 0.37) < smoothstep(x_quente - 0.35, x_quente + 0.25, SCREEN_UV.x) ? papel_quente.rgb : papel_frio.rgb;
	ALBEDO = g < cob ? tinta : papel;
}
