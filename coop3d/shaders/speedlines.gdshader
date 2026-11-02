// Anime-style radial speed lines (launch rings, dashes, big moments)
// plus a soft vignette that the hit-flash also uses.
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.25;
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float aspect = 1.777;

float h(float x) {
	return fract(sin(x * 91.7) * 47453.5);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float id = floor(a * 40.0 + floor(TIME * 24.0) * 7.0);
	float line = step(0.6, h(id)) * smoothstep(0.35, 0.95, r) * intensity;
	float vig = smoothstep(0.45, 1.1, r) * vignette;
	vec3 col = mix(vec3(0.15, 0.05, 0.25), vec3(1.0), line);
	float alpha = max(line * 0.55, vig);
	COLOR = vec4(mix(col, flash.rgb, flash.a), max(alpha, flash.a));
}
