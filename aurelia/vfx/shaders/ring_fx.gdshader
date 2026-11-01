// Hollow expanding ring (shell only - the middle stays empty so additive never blows out).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float width = 0.16;
uniform bool facing_camera = true;

void vertex() {
	if (facing_camera) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float r = mix(0.15, 1.0, 1.0 - pow(1.0 - progress, 3.0));
	float w = width * (1.0 - progress * 0.7);
	float band = smoothstep(w, 0.0, abs(d - r));
	ALBEDO = color.rgb * (0.8 + band);
	ALPHA = band * (1.0 - progress) * color.a;
}
