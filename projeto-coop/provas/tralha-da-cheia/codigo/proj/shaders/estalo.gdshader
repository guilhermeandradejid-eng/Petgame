// Estrela de estalo recortada (contato): miolo creme, pontas na cor de quem bateu, borda de tinta. 2 a 3 poses.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.85, 0.27, 0.17);
uniform vec3 tinta : source_color = vec3(0.118, 0.102, 0.133);
uniform vec3 creme : source_color = vec3(0.93, 0.88, 0.78);
uniform float semente = 0.0;
uniform float fase = 0.0;
float h(float x) { return fract(sin(x * 91.7 + semente * 13.1) * 43758.5); }
float star(vec2 p, float n, float r0, float r1) {
	float a = atan(p.y, p.x) + semente + fase * 0.4;
	float k = floor(a / (6.2832 / n));
	float f = fract(a / (6.2832 / n));
	float rr = mix(r1, r0 * (0.75 + 0.5 * h(k + fase * 3.0)), 1.0 - abs(f - 0.5) * 2.0);
	return length(p) - rr;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = star(p, 9.0, 0.95, 0.38);
	if (d > 0.0) discard;
	float d2 = star(p * 1.7, 9.0, 0.95, 0.4);
	vec3 c = cor;
	c = mix(c, creme, step(d2, 0.0));
	c = mix(tinta, c, step(d, -0.06));
	ALBEDO = c;
}
