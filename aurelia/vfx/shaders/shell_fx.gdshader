// Generic hollow shell: fresnel rim + scrolling stripes, vertical fade. Used for cyclones, auras,
// the fire ring, the arena barrier. Additive, so the middle stays empty on purpose.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float t = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float stripes = 6.0;
uniform float twist = 3.0;
uniform float speed = 6.0;
uniform float stripe_amt = 0.55;
uniform float rim_amt = 0.8;
uniform float base_alpha = 0.04;
uniform float fresnel_pow = 2.0;
uniform float v_fade = 0.0;          // 0 = uniform, 1 = fades toward UV.y = 1 (top)
uniform float v_fade_bottom = 0.0;   // 1 = fades toward UV.y = 0

void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), fresnel_pow);
	float s = 0.5 + 0.5 * sin(UV.x * stripes * 6.28318 + UV.y * twist - t * speed);
	float vf = mix(1.0, 1.0 - UV.y, v_fade) * mix(1.0, UV.y, v_fade_bottom);
	float a = (base_alpha + f * rim_amt + s * stripe_amt * (0.35 + f)) * vf * fade;
	ALBEDO = mix(color.rgb, vec3(1.0), f * 0.25) * (0.5 + a * 1.4);
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
