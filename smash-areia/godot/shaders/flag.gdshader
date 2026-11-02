// Bandeirinha balançando ao vento
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_a : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 5.0 + k * 6.0 + phase) * 0.18 * k;
	VERTEX.y += sin(TIME * 3.0 + k * 4.0 + phase) * 0.05 * k;
}

void fragment() {
	vec3 col = mix(color_a.rgb, color_b.rgb, step(0.5, fract(UV.y * 2.0)));
	float shade = 0.85 + 0.15 * sin(TIME * 5.0 + UV.x * 6.0 + phase);
	ALBEDO = col * shade;
}
