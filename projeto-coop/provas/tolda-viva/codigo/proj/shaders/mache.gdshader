// Caco de papel machê: tiras de papel creme coladas (faixas com linhas impressas ilegíveis), borda
// rasgada mais clara, sombreado em 2 degraus por tinta. Dupla face.
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 papel : source_color = vec3(0.93, 0.88, 0.76);
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.56, 0.72);
varying vec3 opos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { opos = VERTEX; }
void fragment() {
	vec2 q = opos.xz * 30.0;
	float strip = floor(q.x + 0.3 * q.y);
	vec3 c = papel * (0.9 + 0.12 * h(vec2(strip, 1.0)));
	float line = step(0.82, fract(q.y * 2.2 + h(vec2(strip, 2.0)))) * step(0.3, h(vec2(strip, floor(q.y * 2.2))));
	c = mix(c, c * 0.62, line * 0.7);
	ALBEDO = c;
}
void light() {
	float k = smoothstep(-0.4, -0.36, abs(dot(NORMAL, LIGHT)) - 0.4);
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), k) * LIGHT_COLOR / PI;
}
