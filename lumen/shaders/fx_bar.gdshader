// Barra de vida sempre virada para a camera.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float frac = 1.0;
uniform vec4 fill : source_color = vec4(0.95, 0.3, 0.3, 1.0);
uniform vec4 back : source_color = vec4(0.1, 0.08, 0.16, 0.85);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = abs(UV * 2.0 - 1.0);
	float inner = step(q.x, 0.97) * step(q.y, 0.7);
	vec4 c = (UV.x < frac && inner > 0.5) ? fill : back;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
