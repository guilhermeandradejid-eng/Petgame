shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Papel picado: cada pedaço "vira" no ar (a largura oscila), frente colorida e verso mais escuro.
void vertex() {
	float ph = (COLOR.r * 7.0 + COLOR.g * 13.0 + COLOR.b * 5.0) * 6.2831;
	VERTEX.x *= sin(TIME * 13.0 + ph + VERTEX.y * 2.0);
}
void fragment() {
	vec3 c = COLOR.rgb * (FRONT_FACING ? 1.25 : 0.7);
	float edge = smoothstep(0.0, 0.08, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = c * (0.85 + 0.15 * edge);
}
