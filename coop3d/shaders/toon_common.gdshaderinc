// Shared stylized lighting: 2-tone ramp with tinted shadows, rim light and
// a hard toon highlight. Included by toon.gdshader and terrain.gdshader.
// DIFFUSE_LIGHT is multiplied by ALBEDO by the engine, so the ramp is white
// on the lit side and `shadow_color` on the dark side (stylized bounce).

uniform vec4 shadow_color : source_color = vec4(0.46, 0.42, 0.68, 1.0);
uniform float shade_band : hint_range(-1.0, 1.0) = 0.02;
uniform float shade_soft : hint_range(0.001, 0.5) = 0.07;
uniform float rim_amount : hint_range(0.0, 2.0) = 0.45;
uniform float rim_width : hint_range(0.0, 1.0) = 0.28;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float spec_amount : hint_range(0.0, 2.0) = 0.3;
uniform float spec_size : hint_range(0.0, 1.0) = 0.25;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
				   mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
				   mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// Triplanar "whiteout" blend of a tangent-space normal map in world space.
vec3 triplanar_normal(sampler2D tex, vec3 wp, vec3 wn, float scale) {
	vec3 bl = pow(abs(wn), vec3(4.0));
	bl /= (bl.x + bl.y + bl.z);
	vec3 tx = texture(tex, wp.zy * scale).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, wp.xz * scale).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, wp.xy * scale).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
	ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
	tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
	return normalize(tx.zyx * bl.x + ty.xzy * bl.y + tz.xyz * bl.z);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float atten = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float lit = smoothstep(shade_band, shade_band + shade_soft, ndl) * smoothstep(0.3, 0.7, shadow);
	vec3 ramp = LIGHT_IS_DIRECTIONAL ? mix(shadow_color.rgb, vec3(1.0), lit) : vec3(lit);
	DIFFUSE_LIGHT += ramp * LIGHT_COLOR / PI * atten;

	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.06, fres) * clamp(ndl + 0.6, 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(1.0 - spec_size * 0.08, 1.0 - spec_size * 0.08 + 0.01, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += (rim_color.rgb * rim * rim_amount * 0.5 + spec * spec_amount) * LIGHT_COLOR / PI * atten;
}
