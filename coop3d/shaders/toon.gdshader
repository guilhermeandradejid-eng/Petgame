// General stylized material for characters and props.
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

#include "res://shaders/toon_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float emission_pulse = 0.0;
// procedural color breakup in world space (keeps big surfaces from looking flat)
uniform float noise_tint : hint_range(0.0, 0.5) = 0.0;
uniform float noise_scale = 0.6;
// CC0 detail normal map, sampled triplanar so no UVs are required
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform float detail_scale = 0.5;
// hit flash and dissolve (gates, bridges, defeated enemies)
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge : source_color = vec4(1.0, 0.75, 0.3, 1.0);
// vertex wobble (jelly / wind for foliage)
uniform float wobble = 0.0;
uniform float wobble_speed = 1.5;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wobble > 0.0) {
		float ph = wpos.x * 0.7 + wpos.z * 0.5;
		VERTEX += NORMAL * sin(TIME * wobble_speed + ph + VERTEX.y * 3.0) * wobble;
	}
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = albedo.rgb * texture(albedo_tex, UV).rgb;
	if (noise_tint > 0.0) {
		float n = fbm(wpos * noise_scale);
		col *= mix(1.0 - noise_tint, 1.0 + noise_tint, n);
	}
	vec3 emit = emission.rgb * emission_energy * (1.0 + emission_pulse * sin(TIME * 4.0 + wpos.x + wpos.z));
	if (dissolve > 0.0) {
		float n = fbm(wpos * 2.5);
		if (n < dissolve) {
			discard;
		}
		emit += dissolve_edge.rgb * 6.0 * (1.0 - smoothstep(0.0, 0.06, n - dissolve));
	}
	if (detail_strength > 0.0) {
		vec3 dn = triplanar_normal(detail_normal, wpos, normalize(wnrm), detail_scale);
		vec3 vn = normalize((VIEW_MATRIX * vec4(dn, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, vn, detail_strength));
	}
	ALBEDO = mix(col, flash_color.rgb, hit_flash);
	EMISSION = emit + flash_color.rgb * hit_flash * 0.8;
	ROUGHNESS = 0.8;
}
