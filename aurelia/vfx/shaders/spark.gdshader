// Camera-facing four-point star for hit sparks (additive).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float a = smoothstep(0.16, 0.0, abs(p.x)) * smoothstep(1.0, 0.1, abs(p.y));
	float b = smoothstep(0.16, 0.0, abs(p.y)) * smoothstep(1.0, 0.1, abs(p.x));
	float core = smoothstep(0.35, 0.0, length(p));
	float s = clamp(a + b + core, 0.0, 1.0);
	ALBEDO = COLOR.rgb * (1.0 + core);
	ALPHA = s * COLOR.a;
}
