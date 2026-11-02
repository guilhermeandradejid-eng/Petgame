// Star-shaped iris wipe between scenes, with a wobbly edge.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0 = open, 1 = closed
uniform vec4 color : source_color = vec4(0.18, 0.1, 0.28, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.777;

void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float a = atan(p.y, p.x) + TIME * 0.6;
	float star = 0.82 + 0.18 * cos(a * 5.0);
	float r = length(p) / star;
	float radius = (1.0 - progress) * 1.25;
	float m = smoothstep(radius, radius + 0.01, r);
	float dots = step(0.5, fract((UV.x + UV.y) * 40.0)) * 0.04;
	COLOR = vec4(color.rgb + dots, m);
}
