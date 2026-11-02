shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color : source_color = vec4(0.1, 0.08, 0.15, 1.0);
uniform vec2 cells = vec2(90.0, 10.0);

void fragment() {
	vec2 g = fract(UV * cells);
	float line = step(g.x, 0.12) + step(g.y, 0.12);
	if (line < 0.5) {
		discard;
	}
	ALBEDO = color.rgb;
}
