// Rastro da raquete: meia-lua branca que some (smear de desenho animado)
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	float a = pow(UV.x, 1.5) * smoothstep(0.0, 0.3, UV.y);
	ALBEDO = mix(color.rgb, vec3(1.0), UV.y * 0.6);
	ALPHA = a * 0.75;
}
