// Dimensional rift: a disc (turned toward the camera by rift.gd) with a swirling polar-coordinate
// vortex, chromatic crackling rim and a dark core. `open` scales it in/out.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 color_a : source_color = vec4(0.62, 0.32, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.07, 0.02, 0.18, 1.0);
uniform float open : hint_range(0.0, 1.0) = 1.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv) / max(open, 0.001);
	float a = atan(uv.y, uv.x);
	float swirl = a / TAU + r * 1.6 - TIME * 0.35;
	float v = n(vec2(swirl * 8.0, r * 4.0 - TIME * 1.5));
	float v2 = n(vec2(swirl * 14.0 + 3.0, r * 7.0 - TIME * 2.2));
	float edge_wobble = 0.08 * sin(a * 7.0 + TIME * 5.0) + 0.06 * v2;
	float disc = 1.0 - smoothstep(0.82 + edge_wobble, 0.9 + edge_wobble, r);
	float rim = smoothstep(0.55, 0.85 + edge_wobble, r) * disc;
	vec3 col = mix(core.rgb, mix(color_a.rgb, color_b.rgb, v), smoothstep(0.1, 0.8, r) * (0.5 + v * 0.8));
	col += rim * mix(color_b.rgb, vec3(1.0), v2) * 2.0;
	ALBEDO = col;
	EMISSION = col * 1.5;
	ALPHA = disc * open;
}
