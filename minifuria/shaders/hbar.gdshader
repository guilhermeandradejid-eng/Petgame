shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Barra de vida sobre os carros rivais (sempre de frente para a câmera).
uniform float ratio = 1.0;
uniform vec4 col : source_color = vec4(1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float border = step(uv.x, 0.03) + step(0.97, uv.x) + step(uv.y, 0.18) + step(0.82, uv.y);
	vec3 fill = mix(vec3(1.0, 0.15, 0.1), vec3(0.35, 1.0, 0.3), ratio);
	vec3 c = uv.x < ratio ? fill * 1.4 : vec3(0.08, 0.06, 0.12);
	c = mix(c, col.rgb * 0.6, clamp(border, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = 0.92;
}
