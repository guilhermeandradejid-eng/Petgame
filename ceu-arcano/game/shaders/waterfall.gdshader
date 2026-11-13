shader_type canvas_item;
// Cachoeira: faixas descendo em pixel art.

uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	float t = TIME * 40.0;
	float col_id = floor(UV.x * 4.0);
	float stripe = hash(vec2(col_id + seed, floor((UV.y * 60.0 - t * (0.8 + hash(vec2(col_id, seed)) * 0.4)) / 3.0)));
	vec3 base = vec3(0.55, 0.72, 0.95);
	vec3 c = mix(base, vec3(0.92, 0.97, 1.0), step(0.72, stripe));
	float fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	COLOR = vec4(c, 0.75 * fade);
}
