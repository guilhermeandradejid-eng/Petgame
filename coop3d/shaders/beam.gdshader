// Flowing energy ribbon (light tether, launch trails). UV.x runs along the
// ribbon, UV.y across it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 color2 : source_color = vec4(0.4, 1.0, 0.9, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float core = smoothstep(0.5, 1.0, across);
	float flow = 0.5 + 0.5 * sin(UV.x * 30.0 - TIME * 18.0);
	vec3 c = mix(color.rgb, color2.rgb, 0.5 + 0.5 * sin(UV.x * 6.0 + TIME * 4.0));
	ALBEDO = c;
	ALPHA = clamp((across * across * 0.6 + core) * (0.6 + 0.4 * flow) * intensity, 0.0, 1.0);
	EMISSION = (c + vec3(core)) * ALPHA * 2.0;
}
