// Rotating rune ring on the ground. Lines only, so it stays a hollow shell.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float t = 0.0;        // seconds, drives rotation
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float line(float d, float w) { return smoothstep(w, 0.0, abs(d)); }

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + t * 1.4;
	float outer = line(r - 0.92, 0.025);
	float inner = line(r - 0.70, 0.02);
	// 12 rune ticks between the rings
	float tick_a = abs(fract(a / 6.28318 * 12.0) - 0.5);
	float ticks = smoothstep(0.08, 0.0, tick_a) * step(0.72, r) * step(r, 0.9);
	// hexagram: two triangles
	float h = 0.0;
	for (int i = 0; i < 6; i++) {
		float ang = float(i) * 1.0472 + t * -0.9;
		vec2 dir = vec2(cos(ang), sin(ang));
		h = max(h, line(dot(p, dir) - 0.34, 0.018) * step(r, 0.72));
	}
	float s = clamp(outer + inner * 0.8 + ticks * 0.9 + h * 0.7, 0.0, 1.0);
	ALBEDO = color.rgb * (0.9 + s);
	ALPHA = s * fade * color.a * smoothstep(1.0, 0.9, r);
}
