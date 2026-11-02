shader_type spatial;
render_mode unshaded;

uniform vec4 sand : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.93, 0.73, 0.47, 1.0);
uniform vec4 wet : source_color = vec4(0.82, 0.66, 0.45, 1.0);
uniform float shore_z = -24.0;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wpos.xz * 0.35) * 0.6 + noise(wpos.xz * 1.3) * 0.4;
	vec3 col = mix(sand.rgb, sand_dark.rgb, step(0.62, n) * 0.6);
	float speck = step(0.93, hash(floor(wpos.xz * 9.0)));
	col = mix(col, sand_dark.rgb * 0.92, speck * 0.5);
	// dunas: listras suaves
	float dune = smoothstep(0.45, 0.5, fract(wpos.z * 0.08 + noise(wpos.xz * 0.05) * 1.5));
	col *= mix(1.0, 0.97, dune);
	float wetness = smoothstep(shore_z + 6.0, shore_z + 1.5, wpos.z);
	col = mix(col, wet.rgb, wetness);
	col *= vec3(1.02, 0.99, 0.95);
	col = mix(col, vec3(1.0, 0.84, 0.72), smoothstep(45.0, 300.0, length(VERTEX)) * 0.7);
	ALBEDO = col;
}
