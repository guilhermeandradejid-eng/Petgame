// Explosão de impacto em billboard (estrela de gibi que cresce e some)
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float t = 0.0;
uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + seed;
	float r = length(p);
	float spikes = 0.55 + 0.45 * step(0.0, sin(a * 7.0));
	float grow = 0.35 + 0.65 * sqrt(t);
	float outer = spikes * grow;
	float inner = outer * smoothstep(0.0, 1.0, t) * 0.85;
	float ring = step(r, outer) * step(inner, r);
	float ink = step(r, outer + 0.06) * step(inner - 0.06, r) * (1.0 - ring);
	vec3 col = mix(vec3(0.07, 0.04, 0.12), mix(vec3(1.0), color.rgb, smoothstep(0.0, 0.6, r)), ring);
	ALBEDO = col;
	ALPHA = (ring + ink) * (1.0 - smoothstep(0.6, 1.0, t));
}
