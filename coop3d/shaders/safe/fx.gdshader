// Safe-mode stand-in for the transparent effect shaders
// (ghost, portal, shockwave, beam, bubble).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float progress = 0.0;
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = 0.35 * (1.0 - progress);
}
