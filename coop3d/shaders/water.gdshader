// Stylized toon water (river, pools) and waterfalls (`fall` = 1).
// Waves are summed sines in the vertex shader; the surface gets banded
// color, a fresnel sky tint, drifting foam streaks from noise, and foam
// where the water meets the shore (depth-buffer intersection).
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_toon, blend_mix;

uniform vec4 deep : source_color = vec4(0.16, 0.5, 0.78, 1.0);
uniform vec4 shallow : source_color = vec4(0.35, 0.85, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec2 flow = vec2(0.0, 0.25);
uniform float wave = 0.06;
uniform float fall = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 wpos;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (fall < 0.5) {
		VERTEX.y += (sin(w.x * 0.8 + TIME * 1.6) + sin(w.z * 1.1 - TIME * 1.3)) * wave;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (fall > 0.5) ? vec2(UV.x * 6.0, UV.y * 3.0 - TIME * 2.2) : wpos.xz * 0.35 + flow * TIME;
	float n = n2(uv * 1.7);
	float n_b = n2(uv * 4.3 + 7.0);
	float streak = smoothstep(0.62, 0.7, n * 0.7 + n_b * 0.3);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep.rgb, shallow.rgb, floor((n * 0.6 + fres) * 3.0) / 3.0);

	// shoreline foam: compare scene depth with this surface's depth
	float shore = 0.0;
	if (fall < 0.5) {
		float raw = texture(depth_tex, SCREEN_UV).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
		float scene_z = -vp.z / vp.w;
		float thick = scene_z - (-VERTEX.z);
		shore = 1.0 - smoothstep(0.0, 0.55 + n_b * 0.3, thick);
	}
	float f = clamp(streak + shore, 0.0, 1.0);
	if (fall > 0.5) {
		f = smoothstep(0.45, 0.6, n) * 0.8 + smoothstep(0.85, 1.0, UV.y) * 0.9;
	}
	ALBEDO = mix(col, foam.rgb, f);
	ROUGHNESS = 0.15;
	EMISSION = foam.rgb * f * 0.15;
	ALPHA = (fall > 0.5) ? 0.85 : mix(0.82, 1.0, f);
}
