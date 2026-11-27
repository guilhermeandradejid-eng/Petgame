// Lasca pintada (e pétala de água): cor da tinta em cima, miriti cru nos lados (cor de vértice), toon de 3 degraus.
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 cor : source_color = vec3(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.56, 0.50, 0.70);
uniform float brilho = 0.0;
uniform float alfa = 1.0;
uniform float plano = 0.0;    // 1: chapado (pétala de água), quase sem luz
void fragment() {
	vec3 vc = COLOR.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vc = mix(vc * 12.92, 1.055 * pow(vc, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), vc));
#endif
	vec3 c = (vc.r > 0.99 && vc.g > 0.99) ? cor : vec3(0.93, 0.88, 0.78);
	if (plano > 0.5) c = cor;
	ALBEDO = c;
	EMISSION = c * brilho + c * plano * 0.55;
	if (alfa < 0.999) {
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > alfa) discard;
	}
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k1 = smoothstep(-0.03, 0.03, ndl) * ATTENUATION;
	float k2 = smoothstep(0.42, 0.48, ndl) * ATTENUATION;
	vec3 lv = mix(mix(shadow_tint, vec3(0.74), k1), vec3(1.0), k2);
	DIFFUSE_LIGHT += mix(lv, vec3(0.45), plano) * LIGHT_COLOR / PI;
}
