// Estrela de "chance" no chão: gire e brilhe onde dá para soltar um golpe forte
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.4, 1.0);
uniform float amount = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + TIME * 2.0;
	float r = length(p);
	float star = 0.5 + 0.38 * pow(abs(cos(a * 2.5)), 3.0);
	float fill = 1.0 - smoothstep(star - 0.05, star, r);
	float ink = (1.0 - smoothstep(star + 0.02, star + 0.08, r)) * (1.0 - fill);
	float glow = smoothstep(1.0, 0.4, r) * 0.35 * (0.6 + 0.4 * sin(TIME * 12.0));
	vec3 col = mix(color.rgb, vec3(1.0), smoothstep(0.25, 0.0, r));
	ALBEDO = mix(col, vec3(0.07, 0.04, 0.12), ink);
	ALPHA = clamp(fill * 0.9 + ink + glow, 0.0, 1.0) * amount;
}
