// Esferas e cascas de energia (orbes, explosoes, escudos): brilho de borda + miolo opcional.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;

uniform vec4 color : source_color = vec4(1.0);
uniform float rim_power = 2.0;
uniform float core = 0.0;
uniform float fade = 1.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float f = pow(1.0 - ndv, rim_power);
	float c = pow(ndv, 2.5) * core;
	ALBEDO = mix(color.rgb, vec3(1.0), c * 0.6);
	ALPHA = clamp(f + c, 0.0, 1.0) * color.a * fade;
}
