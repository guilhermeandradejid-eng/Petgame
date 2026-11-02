shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);

void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(color.rgb, vec3(1.0), smoothstep(0.6, 1.0, edge));
	ALPHA = UV.x * smoothstep(0.0, 0.25, edge) * color.a;
}
