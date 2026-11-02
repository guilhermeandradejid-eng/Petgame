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
	vec3 col = color.rgb;
	if (ring > 0.5) {
		float rr = 0.74 + sin(TIME * 10.0) * 0.05 * pulse;
		float core = smoothstep(0.13, 0.07, abs(r - rr));
		// tracejado
		float ang = atan(p.y, p.x);
		core *= step(0.0, sin(ang * 8.0 + TIME * 4.0)) * 0.6 + 0.4;
		float dot_c = smoothstep(0.18, 0.11, r);
		core = max(core, dot_c);
		// faixa de tinta por baixo: o anel se destaca na areia clara
		float ink = max(smoothstep(0.22, 0.15, abs(r - rr)), smoothstep(0.24, 0.17, r));
		col = mix(vec3(0.07, 0.04, 0.12), color.rgb, core);
		a = max(core, ink * 0.75);
	} else {
		a = smoothstep(1.0, 0.7, r);
	}
	ALBEDO = col;
	ALPHA = color.a * a;
}
