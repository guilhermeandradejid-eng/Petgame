// Triplanar stylized terrain: grassy tops, layered rock sides.
// "Up" is either world up or radial from a planet center (planetoids).
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

#include "res://shaders/toon_common.gdshaderinc"

uniform vec4 grass_a : source_color = vec4(0.42, 0.78, 0.33, 1.0);
uniform vec4 grass_b : source_color = vec4(0.62, 0.88, 0.38, 1.0);
uniform vec4 rock_a : source_color = vec4(0.74, 0.55, 0.43, 1.0);
uniform vec4 rock_b : source_color = vec4(0.58, 0.41, 0.36, 1.0);
uniform float grass_only = 0.0;
uniform float rock_only = 0.0;
uniform bool radial = false;
uniform vec3 planet_center = vec3(0.0);
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.7;
uniform float tex_scale = 0.35;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 up = radial ? normalize(wpos - planet_center) : vec3(0.0, 1.0, 0.0);
	float slope = dot(n, up);
	float edge_noise = fbm(wpos * 1.3) * 0.25;
	float g = smoothstep(0.55, 0.7, slope + edge_noise);
	g = clamp(g + grass_only - rock_only, 0.0, 1.0);

	// grass: large soft patches + tiny speckles
	float patches = fbm(wpos * 0.18);
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.35, 0.65, patches));
	grass *= 0.92 + 0.16 * vnoise(wpos * 6.0);
	// rock: horizontal strata bands warped by noise
	float h = dot(wpos, up) + fbm(wpos * 0.5) * 1.5;
	float strata = smoothstep(0.4, 0.6, fract(h * 0.9));
	vec3 rock = mix(rock_a.rgb, rock_b.rgb, strata * 0.6 + 0.2 * vnoise(wpos * 3.0));

	ALBEDO = mix(rock, grass, g);
	vec3 dn = mix(triplanar_normal(rock_normal, wpos, n, tex_scale), triplanar_normal(grass_normal, wpos, n, tex_scale * 2.0), g);
	vec3 vn = normalize((VIEW_MATRIX * vec4(dn, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, vn, normal_strength * (1.0 - g * 0.6)));
	ROUGHNESS = 0.9;
}
