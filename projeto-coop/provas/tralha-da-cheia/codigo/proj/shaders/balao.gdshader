// Balão de "me passa!": pictograma (mão aberta pedindo), sem texto, na cor de quem pediu.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.85, 0.27, 0.17);
uniform vec3 tinta : source_color = vec3(0.118, 0.102, 0.133);
uniform vec3 creme : source_color = vec3(0.93, 0.88, 0.78);
float sdbox(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float bub = length(p * vec2(1.0, 1.1) - vec2(0.0, 0.12)) - 0.78;
	vec2 t = p - vec2(-0.18, -0.72);
	float tail = max(abs(t.x + t.y * 0.4) - 0.16 * (1.0 + t.y * 1.4), -t.y - 0.25);
	tail = max(tail, t.y - 0.1);
	float s = min(bub, tail);
	if (s > 0.06) discard;
	// mão aberta de 3 dedos (palma + 3 blocos + polegar), como as mãos dos bonecos
	vec2 q = p - vec2(0.0, 0.05);
	float palm = sdbox(q - vec2(0.0, -0.12), vec2(0.2, 0.17));
	float f1 = sdbox(q - vec2(-0.14, 0.2), vec2(0.055, 0.16));
	float f2 = sdbox(q - vec2(0.0, 0.25), vec2(0.055, 0.2));
	float f3 = sdbox(q - vec2(0.14, 0.2), vec2(0.055, 0.16));
	float th = sdbox(vec2((q.x + 0.26) * 0.7 - (q.y + 0.08) * 0.7, (q.x + 0.26) * 0.7 + (q.y + 0.08) * 0.7), vec2(0.05, 0.12));
	float hand = min(min(palm, th), min(f1, min(f2, f3)));
	vec3 c = cor;
	c = mix(c, creme, step(hand, 0.0));
	c = mix(c, tinta, step(abs(hand), 0.025));
	c = mix(tinta, c, step(s, 0.0));
	ALBEDO = c;
}
