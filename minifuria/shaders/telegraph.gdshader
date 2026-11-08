shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// aviso no chão dos ataques de chefe: círculo que "enche" até o golpe (arm 0->1); mode 1 = chão em chamas
uniform vec4 col : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float arm = 0.0;
uniform float tt = 0.0;
uniform float mode = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (mode > 3.5) {
		// gelo liso: azul claro com brilho correndo
		float edge = smoothstep(1.0, 0.8, max(abs(p.x), abs(p.y)));
		float shine = smoothstep(0.1, 0.0, abs(fract(p.x * 0.5 + p.y * 0.3 + tt * 0.6) - 0.5));
		ALBEDO = (vec3(0.55, 0.85, 1.0) * 0.6 + vec3(1.0) * shine * 0.6) * edge * (arm < 0.999 ? 0.35 + 0.3 * sin(tt * 16.0) : 0.9);
	} else if (mode > 2.5) {
		// lama: manchas marrons borbulhando
		float n = sin(p.x * 7.0 + tt * 2.0) * sin(p.y * 6.0 - tt * 1.7);
		float edge = smoothstep(1.0, 0.7, length(p));
		ALBEDO = vec3(0.45, 0.3, 0.12) * edge * (0.6 + 0.4 * n) * (arm < 0.999 ? 0.4 + 0.3 * sin(tt * 14.0) : 1.0);
	} else if (mode > 1.5) {
		// faixa de bloqueio: retângulo piscando (a brecha é marcada com cones)
		float edge = smoothstep(1.0, 0.85, abs(p.y)) * step(abs(p.x), 1.0);
		float blink = 0.55 + 0.45 * sin(tt * (10.0 + arm * 18.0));
		float stripes = step(0.5, fract((p.x + p.y) * 6.0));
		ALBEDO = col.rgb * edge * (0.35 + stripes * 0.4) * (arm < 0.999 ? blink : 0.5) * 2.0;
	} else if (mode > 0.5) {
		// faixa de fogo: chamas animadas preenchendo o retângulo
		float n = sin(p.x * 9.0 + tt * 7.0) * 0.5 + sin(p.y * 13.0 - tt * 11.0) * 0.5;
		float edge = smoothstep(1.0, 0.75, max(abs(p.x), abs(p.y)));
		float a = clamp(0.55 + 0.35 * n, 0.0, 1.0) * edge * arm;
		ALBEDO = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.3), clamp(n, 0.0, 1.0)) * a * 2.5;
	} else {
		float ring = smoothstep(0.08, 0.0, abs(r - 0.96));
		float fill = step(r, arm) * 0.35 * step(r, 1.0);
		float blink = 0.6 + 0.4 * sin(tt * (8.0 + arm * 20.0));
		float a = (ring * blink + fill) * step(arm, 0.999) + step(0.999, arm) * ring * 0.2;
		ALBEDO = col.rgb * a * 2.0;
	}
}
