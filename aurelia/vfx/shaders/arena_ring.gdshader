// The battle arena floor: a glowing hollow ring with marching runes and a faint tinted interior.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float t = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float ring = smoothstep(0.035, 0.0, abs(d - 0.965));
	float ring2 = smoothstep(0.02, 0.0, abs(d - 0.90)) * 0.6;
	float dash = step(0.5, fract(a / 6.28318 * 56.0 + t * 0.3)) * smoothstep(0.05, 0.0, abs(d - 0.93));
	float runes = step(0.82, fract(a / 6.28318 * 18.0 - t * 0.15)) * smoothstep(0.045, 0.0, abs(d - 0.84)) * 0.8;
	float inner = smoothstep(1.0, 0.4, d) * 0.035 * (0.7 + 0.3 * sin(t * 2.0));
	float s = (ring + ring2 + dash * 0.7 + runes + inner) * step(d, 1.0) * fade;
	ALBEDO = color.rgb * (0.8 + s);
	ALPHA = clamp(s, 0.0, 1.0);
}
