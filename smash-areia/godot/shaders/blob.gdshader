// Sombra redonda no chão / anel de alvo
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.25, 0.12, 0.2, 0.45);
uniform float ring = 0.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a;
	if (ring > 0.5) {
		float rr = 0.78 + sin(TIME * 10.0) * 0.06 * pulse;
		a = smoothstep(0.17, 0.1, abs(r - rr));
		// tracejado
		float ang = atan(p.y, p.x);
		a *= step(0.0, sin(ang * 8.0 + TIME * 4.0)) * 0.6 + 0.4;
		a = max(a, smoothstep(0.2, 0.12, r));
	} else {
		a = smoothstep(1.0, 0.7, r);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a * a;
}
