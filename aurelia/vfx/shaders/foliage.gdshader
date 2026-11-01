// Toon-ish foliage/rock material with vertex-colour tint and optional wind sway.
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.2, 0.5, 0.25, 1.0);
uniform vec4 light_color : source_color = vec4(0.5, 0.78, 0.3, 1.0);
uniform float sway = 0.0;

varying vec3 wn;

void vertex() {
	float k = sway * (VERTEX.y > 0.0 ? 1.0 : 0.0);
	VERTEX.x += sin(TIME * 1.3 + MODEL_MATRIX[3].x * 0.6 + MODEL_MATRIX[3].z) * k * 0.06 * VERTEX.y;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float up = clamp(wn.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 c = mix(base_color.rgb, light_color.rgb, smoothstep(0.35, 0.95, up));
	ALBEDO = c * (0.85 + COLOR.r * 0.3);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
