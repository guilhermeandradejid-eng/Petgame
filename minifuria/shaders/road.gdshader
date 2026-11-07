shader_type spatial;
render_mode cull_disabled;
// Pista procedural: UV.x = 0..1 na largura, UV.y = metros ao longo da pista.
// mode 0 asfalto, 1 plástico laranja (brinquedo), 2 asfalto com gelo, 3 placas de metal.
uniform float W = 22.0;
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool two_way = true;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float x = UV.x * W;
	float y = UV.y;
	vec2 q = vec2(x, y);
	float n = noise(q * 0.35) * 0.45 + noise(q * 2.5) * 0.3 + hash(floor(q * 14.0)) * 0.25;
	float edge_ao = smoothstep(0.0, 1.6, min(x, W - x));     // escurece perto da zebra
	vec3 c;
	float rough = 0.85;
	float spec = 0.35;
	if (mode == 1) {
		c = vec3(1.0, 0.42, 0.05) * (0.92 + n * 0.12);
		float stripe = step(abs(x - W * 0.5), 0.25) * step(fract(y / 6.0), 0.55);
		c = mix(c, vec3(1.0, 0.95, 0.85), stripe);
		float side = step(abs(x - 1.2), 0.15) + step(abs(x - (W - 1.2)), 0.15);
		c = mix(c, vec3(1.0, 0.7, 0.2), side);
		rough = 0.3;
		spec = 0.6;
	} else if (mode == 3) {
		vec2 g = fract(q / vec2(W / 4.0, 4.0));
		float seam = step(g.x, 0.02) + step(g.y, 0.03);
		c = vec3(0.42, 0.43, 0.47) * (0.85 + n * 0.25);
		c *= 1.0 - 0.45 * clamp(seam, 0.0, 1.0);
		float bolt = step(length(fract(q / vec2(W / 4.0, 4.0)) - vec2(0.08, 0.12)), 0.03);
		c = mix(c, vec3(0.7), bolt);
		rough = 0.45;
		spec = 0.55;
	} else {
		c = vec3(0.36, 0.37, 0.41) * (0.84 + n * 0.28);
		c *= 1.0 - 0.18 * smoothstep(0.62, 0.8, noise(q * 0.12 + 7.0));
		if (mode == 2) {
			float ice = smoothstep(0.55, 0.75, noise(q * 0.08 + 3.0));
			c = mix(c, vec3(0.82, 0.9, 1.0), ice * 0.7);
			rough = mix(0.85, 0.15, ice);
			spec = mix(0.35, 0.8, ice);
		}
		float edge = step(0.5, x) * step(x, 0.85) + step(W - 0.85, x) * step(x, W - 0.5);
		float cx = abs(x - W * 0.5);
		float dash = step(fract(y / 11.0), 0.5);
		float lane;
		vec3 mid_col;
		float mid;
		if (two_way) {
			mid = step(0.2, cx) * step(cx, 0.42);
			mid_col = vec3(1.0, 0.75, 0.16);
			lane = (step(abs(x - W * 0.25), 0.12) + step(abs(x - W * 0.75), 0.12)) * dash;
		} else {
			mid = step(cx, 0.14) * dash;
			mid_col = vec3(0.94, 0.93, 0.89);
			lane = 0.0;
		}
		c = mix(c, vec3(0.94, 0.93, 0.89), clamp(edge + lane, 0.0, 1.0));
		c = mix(c, mid_col, mid);
	}
	c *= tint.rgb;
	c *= mix(0.72, 1.0, edge_ao);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
