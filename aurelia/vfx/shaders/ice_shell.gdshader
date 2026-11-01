// Hollow crystalline shell: alpha comes from fresnel + facet scroll, the core stays near-transparent.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform float t = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float facets = 0.5 + 0.5 * sin(UV.x * 40.0 + UV.y * 24.0 - t * 14.0);
	float rim = clamp(f * 1.35 + facets * 0.10, 0.0, 1.0);
	ALBEDO = mix(color.rgb, vec3(0.9, 1.0, 1.0), f * 0.5) * (0.35 + rim * 1.4);
	ALPHA = (0.07 + rim * 0.75) * fade;
}
