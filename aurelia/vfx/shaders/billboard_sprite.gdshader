// Upright (Y-fixed) billboard for pixel sprites, lit by the 3D stage via a generated normal map.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform sampler2D nsheet : filter_nearest, repeat_disable;
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip = 1.0;                       // 1 = faces right, -1 = mirrored
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 squash = vec2(1.0, 1.0);
uniform float skew = 0.0;               // lean: shifts the top of the sprite sideways
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0; // warm self-illumination (windup telegraph)
uniform float cell_px = 64.0;

void vertex() {
	VERTEX.x *= squash.x;
	VERTEX.y *= squash.y;
	VERTEX.x += skew * max(VERTEX.y, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	if (flip < 0.0) {
		uv.x = 1.0 - uv.x;
	}
	vec2 suv = frame_rect.xy + uv * frame_rect.zw;
	vec4 c = texture(sheet, suv);
	if (c.a < 0.5) {
		discard;
	}
	vec3 edge_glow = vec3(0.0);
	if (dissolve > 0.0) {
		vec2 px = floor(uv * cell_px);
		float h = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453);
		if (h < dissolve) {
			discard;
		}
		edge_glow = vec3(1.0, 0.55, 0.2) * smoothstep(dissolve + 0.18, dissolve, h) * 1.4;
	}
	vec3 n = texture(nsheet, suv).rgb * 2.0 - 1.0;
	n.x *= flip;
	vec3 right_w = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 back_w = normalize(cross(right_w, vec3(0.0, 1.0, 0.0)));
	vec3 wn = right_w * n.x + vec3(0.0, 1.0, 0.0) * n.y + back_w * n.z;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = mix(c.rgb * tint.rgb, flash_color.rgb, flash);
	EMISSION = flash_color.rgb * flash * 0.9 + edge_glow + c.rgb * glow * vec3(0.5, 0.25, 0.05);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
