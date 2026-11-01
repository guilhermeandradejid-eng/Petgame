// Painterly grass + dirt path ground, driven by world position (no textures needed).
shader_type spatial;
render_mode cull_back;

uniform vec4 grass_a : source_color = vec4(0.13, 0.33, 0.16, 1.0);
uniform vec4 grass_b : source_color = vec4(0.24, 0.46, 0.17, 1.0);
uniform vec4 dirt : source_color = vec4(0.42, 0.31, 0.2, 1.0);
uniform vec4 flowers : source_color = vec4(1.0, 0.85, 0.45, 1.0);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = vnoise(p * 0.35) * 0.6 + vnoise(p * 1.7) * 0.4;
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.75, n));
	// winding path through the glade
	float pc = sin(p.y * 0.18) * 4.5 + sin(p.y * 0.07 + 1.0) * 3.0;
	float path = smoothstep(2.4, 1.2, abs(p.x - pc) + (vnoise(p * 0.9) - 0.5) * 1.6);
	g = mix(g, dirt.rgb * (0.85 + vnoise(p * 3.0) * 0.3), path);
	// tiny flowers (pixel-sized specks)
	vec2 cell = floor(p * 2.5);
	float fl = step(0.965, hash(cell)) * (1.0 - path) * step(length(fract(p * 2.5) - 0.5), 0.16);
	g = mix(g, flowers.rgb, fl);
	ALBEDO = g;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
