shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.45;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.04, 0.03, 0.08);
	ALPHA = smoothstep(1.0, 0.25, d) * strength;
}
