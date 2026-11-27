// Boneco: cor de vértice chapada (madeira pintada) ou chita (textura), toon de 2 degraus por light().
// Sombra = multiplicar por uma tinta única (regra 6), nunca preto.
shader_type spatial;
render_mode cull_back, specular_disabled, shadows_disabled;
uniform sampler2D chita : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_chita = false;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.50, 0.64);
uniform float band = -0.05;
uniform float soft = 0.015;
void fragment() {
	vec3 vc = COLOR.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// no Compatibility (4.7.2) a cor de vértice chega ao shader já convertida sRGB->linear uma segunda vez:
	// desfaz para ficar igual ao Forward+ (medido: #E0B54A saía (190,117,13) sem isto)
	vc = mix(vc * 12.92, 1.055 * pow(vc, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), vc));
#endif
	vec3 c = use_chita ? texture(chita, UV).rgb : vc;
	ALBEDO = c;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k = smoothstep(band - soft, band + soft, ndl);
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), k) * ATTENUATION * LIGHT_COLOR / PI;
}
