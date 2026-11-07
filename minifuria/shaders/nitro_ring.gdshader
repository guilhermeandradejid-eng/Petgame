shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Onda de choque do nitro: anel fino no ar, brilhando nas bordas e sumindo.
uniform float fade = 1.0;
uniform vec4 col : source_color = vec4(0.45, 0.85, 1.0, 1.0);

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float a = (0.25 + pow(rim, 1.6)) * fade;
	ALBEDO = col.rgb * (1.6 + rim * 2.0);
	ALPHA = clamp(a, 0.0, 1.0);
}
