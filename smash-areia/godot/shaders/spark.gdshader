// Faísca/estrelinha em billboard para partículas (cor vem da partícula)
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float star = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float r = length(p);
	float edge = mix(0.85, 0.45 + 0.4 * pow(abs(cos(a * 2.0)), 6.0), star);
	float m = 1.0 - smoothstep(edge - 0.12, edge, r);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), smoothstep(0.35, 0.0, r) * 0.7);
	ALPHA = m * COLOR.a;
}
