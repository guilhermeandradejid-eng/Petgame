// Additive silhouette used for dash afterimages.
shader_type spatial;
render_mode cull_disabled, unshaded, blend_add, depth_draw_never;

uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip = 1.0;
uniform vec4 color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float alpha = 0.6;
uniform vec2 squash = vec2(1.0, 1.0);
uniform float skew = 0.0;               // lean: shifts the top of the sprite sideways

void vertex() {
	VERTEX.x *= squash.x;
	VERTEX.y *= squash.y;
	VERTEX.x += skew * max(VERTEX.y, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	if (flip < 0.0) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(sheet, frame_rect.xy + uv * frame_rect.zw);
	ALBEDO = color.rgb * alpha;
	ALPHA = c.a > 0.5 ? 1.0 : 0.0;
}
