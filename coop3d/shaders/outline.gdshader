// Inverted-hull outline, used as next_pass of the toon material.
// Width grows a little with distance so far characters keep a readable line.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.16, 0.09, 0.2, 1.0);
uniform float width = 0.012;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = clamp(-view_pos.z * 0.06, 0.6, 2.5);
	VERTEX += normalize(NORMAL) * width * d;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
