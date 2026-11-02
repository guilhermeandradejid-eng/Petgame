// A sea of puffy toon clouds far below the floating islands.
// Vertex displacement makes billowing bumps; the fragment fakes lighting
// from the displaced height and fades into the sky color at distance.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 top_color : source_color = vec4(1.0, 0.97, 0.97, 1.0);
uniform vec4 low_color : source_color = vec4(0.82, 0.74, 0.95, 1.0);
uniform vec4 far_color : source_color = vec4(0.98, 0.82, 0.74, 1.0);
uniform float height = 6.0;
uniform float scale = 0.025;
uniform float fade_dist = 260.0;

varying float vh;
varying vec3 wp;

float hh(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}
float nn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1, 0)), f.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), f.x), f.y);
}
float billow(vec2 p) {
	float s = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		s += (1.0 - abs(nn(p) * 2.0 - 1.0)) * a;
		p *= 2.1;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = w.xz * scale + vec2(TIME * 0.01, TIME * 0.006);
	float b = billow(p);
	vh = b;
	VERTEX.y += b * height;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float shade = smoothstep(0.35, 0.95, vh);
	vec3 col = mix(low_color.rgb, top_color.rgb, floor(shade * 3.0 + 0.5) / 3.0 * 0.7 + shade * 0.3);
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, far_color.rgb, smoothstep(fade_dist * 0.35, fade_dist, d));
	ALBEDO = col;
}
