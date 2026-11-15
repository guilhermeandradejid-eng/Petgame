// Superficie de portal: espiral de luz girando.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 color_a : source_color = vec4(0.49, 0.98, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.55, 0.35, 1.0, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float swirl = sin(ang * 3.0 + r * 9.0 - TIME * 2.6) * 0.5 + 0.5;
	float n = noise(vec2(ang * 2.0 + TIME * 0.6, r * 5.0 - TIME * 1.2));
	vec3 col = mix(color_b.rgb, color_a.rgb, swirl * 0.7 + n * 0.4);
	col += vec3(1.0) * smoothstep(0.35, 0.0, r) * 0.7;
	float a = smoothstep(1.0, 0.86, r);
	ALBEDO = col * 1.6;
	ALPHA = a * (0.75 + 0.25 * swirl);
}
