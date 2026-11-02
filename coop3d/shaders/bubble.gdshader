// Iridescent soap bubble that carries a fallen player back to the partner.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 tint : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float wobble = 0.04;

void vertex() {
	VERTEX += NORMAL * sin(TIME * 6.0 + VERTEX.y * 8.0 + VERTEX.x * 5.0) * wobble;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float t = fres * 3.0 + TIME * 0.6 + NORMAL.y * 2.0;
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + t));
	vec3 hl = vec3(smoothstep(0.93, 0.96, dot(NORMAL, normalize(vec3(-0.4, 0.6, 0.7)))));
	ALBEDO = mix(tint.rgb, irid, 0.6) + hl;
	EMISSION = hl * 2.0 + irid * fres * 0.4;
	ALPHA = clamp(0.08 + fres * 0.75 + hl.x, 0.0, 1.0);
}
