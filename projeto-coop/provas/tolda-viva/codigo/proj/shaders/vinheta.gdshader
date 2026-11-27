// Vinheta de palco (v2): escurece as bordas do quadro em degrau largo e suave, para o centro
// iluminado funcionar como palco. Multiplica; presa à câmera, desenhada por cima de tudo.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mul, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.42, 0.38, 0.5);
uniform float forca = 0.55;
uniform float aspect = 1.777;
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(aspect, 1.0) / vec2(aspect, 1.0);
	float r = length(p * vec2(1.0, 0.92));
	float v = smoothstep(0.62, 1.32, r);
	ALBEDO = mix(vec3(1.0), tint, v * forca);
}
