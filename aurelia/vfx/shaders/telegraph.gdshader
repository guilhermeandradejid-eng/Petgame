// Ground warning: hollow outline at the final radius plus a fill that grows until the hit lands.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float outline = smoothstep(0.06, 0.0, abs(d - 0.96));
	float fill = smoothstep(progress + 0.02, progress - 0.04, d) * 0.22;
	float sweep = smoothstep(0.05, 0.0, abs(d - progress)) * 0.55;
	float a = (outline * 0.8 + fill + sweep) * fade * step(d, 1.0);
	ALBEDO = color.rgb * (0.9 + a);
	ALPHA = clamp(a, 0.0, 1.0);
}
