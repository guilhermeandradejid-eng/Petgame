shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
// Mira travada no alvo (sempre de frente para a câmera).
uniform vec4 col : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform float spin = 0.0;
uniform float pulse = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float ang = atan(d.y, d.x) + spin;
	float ring = smoothstep(0.06, 0.0, abs(r - 0.78)) * step(0.35, abs(sin(ang * 2.0)));
	float ticks = smoothstep(0.08, 0.0, abs(r - 0.55)) * step(0.92, abs(cos(ang * 2.0)));
	float dot_c = smoothstep(0.1, 0.0, r);
	float a = max(max(ring, ticks), dot_c * 0.8);
	ALBEDO = col.rgb * (1.4 + pulse * 2.0);
	ALPHA = a * (0.85 + pulse * 0.15);
}
