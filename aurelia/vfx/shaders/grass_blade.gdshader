// Cheap swaying grass tufts (Y-fixed billboards, triangular blades).
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.1, 0.3, 0.14, 1.0);
uniform vec4 tip_color : source_color = vec4(0.36, 0.62, 0.2, 1.0);

varying float h;

void vertex() {
	h = UV.y;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float sway = sin(TIME * 1.8 + MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.5) * 0.09;
	VERTEX.x += sway * (1.0 - UV.y);
}

void fragment() {
	// three blades
	float x = UV.x;
	float y = 1.0 - UV.y;
	float b1 = step(abs(x - 0.30), 0.14 * (1.0 - y));
	float b2 = step(abs(x - 0.52), 0.16 * (1.0 - pow(y, 0.8)));
	float b3 = step(abs(x - 0.72), 0.12 * (1.0 - y * 0.9));
	float a = max(b1 * step(y, 0.8), max(b2, b3 * step(y, 0.7)));
	if (a < 0.5) {
		discard;
	}
	ALBEDO = mix(base_color.rgb, tip_color.rgb, y);
	ROUGHNESS = 1.0;
}
