// Estrela de "chance" no chão: estrela de 5 pontas girando devagar
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.4, 1.0);
uniform float amount = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + TIME * 0.8;
	float r = length(p);
	float k = abs(fract(a * 5.0 / 6.28318) - 0.5) * 2.0;   // 0 na ponta, 1 no vale
	float star = mix(0.92, 0.42, k);
	float fill = 1.0 - smoothstep(star - 0.04, star, r);
	float ink = (1.0 - smoothstep(star + 0.02, star + 0.08, r)) * (1.0 - fill);
	float glow = smoothstep(1.0, 0.4, r) * 0.2 * (0.6 + 0.4 * sin(TIME * 8.0));
	vec3 col = mix(color.rgb, vec3(1.0), smoothstep(0.22, 0.0, r));
	ALBEDO = mix(col, vec3(0.07, 0.04, 0.12), ink);
	ALPHA = clamp(fill * 0.9 + ink + glow, 0.0, 1.0) * amount;
}
