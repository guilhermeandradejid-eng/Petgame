shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Facho de farol (noite): cone aditivo que some com a distância e nas bordas.
uniform vec4 col : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float strength = 0.18;

void fragment() {
	float along = UV.y;                       // 0 no farol, 1 na ponta do cone
	float edge = abs(dot(NORMAL, VIEW));       // centro do cone mais denso que a borda
	float a = (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.08, along) * (0.35 + edge * 0.65);
	ALBEDO = col.rgb * a * strength * 3.0;
	ALPHA = 1.0;
}
