// "Not solid yet" look for inactive bridges / tide blocks: a translucent
// hologram with scrolling stripes and a bright fresnel edge.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 color : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float alpha = 0.28;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float stripes = step(0.5, fract(wpos.y * 4.0 - TIME * 0.8 + wpos.x * 0.5));
	ALBEDO = color.rgb;
	EMISSION = color.rgb * (0.4 + fres);
	ALPHA = clamp(alpha * (0.6 + 0.4 * stripes) + fres * 0.5, 0.0, 1.0);
}
