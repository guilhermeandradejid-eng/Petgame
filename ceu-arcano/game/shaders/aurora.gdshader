shader_type canvas_item;
// Feixe "Cortina de Aurora" da Lumia.

uniform float intensity = 1.0;
uniform float dir = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float x = dir > 0.0 ? uv.x : 1.0 - uv.x;
	float t = TIME;
	float n = noise(vec2(x * 8.0 - t * 3.0, uv.y * 3.0 + t * 0.5));
	float n2 = noise(vec2(x * 22.0 - t * 6.0, uv.y * 9.0));
	float curtain = smoothstep(0.25, 0.9, n * 0.75 + n2 * 0.4);
	float core = 1.0 - smoothstep(0.0, 0.5, abs(uv.y - 0.55 - sin(x * 6.0 - t * 4.0) * 0.08));
	vec3 green = vec3(0.35, 1.0, 0.7);
	vec3 blue = vec3(0.45, 0.75, 1.0);
	vec3 violet = vec3(0.8, 0.45, 1.0);
	vec3 c = mix(mix(violet, blue, uv.y), green, curtain);
	c = mix(c, vec3(1.0), core * 0.6);
	float edge = smoothstep(0.0, 0.06, x) * (1.0 - smoothstep(0.92, 1.0, x));
	float a = (curtain * 0.55 + core * 0.7) * edge * intensity;
	a = floor(a * 6.0) / 6.0;
	COLOR = vec4(c, a);
}
