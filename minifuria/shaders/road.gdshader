shader_type spatial;
render_mode cull_disabled;
// Asfalto procedural: UV.x = 0..1 na largura (22 m), UV.y = metros ao longo da pista.
const float W = 22.0;

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
	vec3 c = vec3(0.27, 0.28, 0.31) * (0.82 + n * 0.3);
	// manchas de óleo
	c *= 1.0 - 0.18 * smoothstep(0.62, 0.8, noise(q * 0.12 + 7.0));
	float edge = step(0.5, x) * step(x, 0.85) + step(W - 0.85, x) * step(x, W - 0.5);
	float cx = abs(x - W * 0.5);
	float yel = step(0.2, cx) * step(cx, 0.42);
	float dash = step(fract(y / 11.0), 0.5);
	float lane = (step(abs(x - 5.5), 0.12) + step(abs(x - 16.5), 0.12)) * dash;
	c = mix(c, vec3(0.94, 0.93, 0.89), clamp(edge + lane, 0.0, 1.0));
	c = mix(c, vec3(1.0, 0.75, 0.16), yel);
	ALBEDO = c;
	ROUGHNESS = 0.88;
}
