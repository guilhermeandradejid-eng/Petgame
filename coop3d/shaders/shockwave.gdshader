// Expanding ground ring for landings, ground pounds and pickups.
// `progress` 0..1 is tweened by Vfx; additive so overlapping rings bloom.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float thickness = 0.12;

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float r = 1.0 - pow(1.0 - progress, 3.0);  // ease-out
	float w = thickness * (1.0 - progress * 0.7);
	float ring = smoothstep(r - w, r, d) - smoothstep(r, r + w * 0.4, d);
	float spokes = 0.75 + 0.25 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 12.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(ring * spokes * (1.0 - progress) * 2.0, 0.0, 1.0);
	EMISSION = color.rgb * ALPHA * 2.0;
}
