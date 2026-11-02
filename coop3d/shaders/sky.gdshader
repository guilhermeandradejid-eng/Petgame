// Stylized procedural sky: gradient, banded sun with halo, drifting toon
// clouds and faint twinkling stars near the zenith.
shader_type sky;
render_mode use_debanding;

uniform vec4 zenith : source_color = vec4(0.32, 0.55, 0.95, 1.0);
uniform vec4 horizon : source_color = vec4(0.98, 0.82, 0.72, 1.0);
uniform vec4 ground : source_color = vec4(0.62, 0.62, 0.86, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 0.98, 0.96, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.78, 0.74, 0.92, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float star_amount : hint_range(0.0, 1.0) = 0.35;

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

float fbm2(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += n2(p) * a;
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 col = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.55, y));
	col = mix(col, ground.rgb, smoothstep(0.0, -0.35, y));

	// sun disk + soft halo (banded for a painterly look)
	vec3 sd = LIGHT0_DIRECTION;
	float sdot = dot(d, sd);
	float halo = smoothstep(0.75, 1.0, sdot);
	col += sun_color.rgb * (floor(halo * 4.0) / 4.0) * 0.18;
	col = mix(col, sun_color.rgb * 1.6, smoothstep(0.9975, 0.998, sdot));

	// clouds projected on a dome
	if (y > -0.05 && !AT_CUBEMAP_PASS) {
		vec2 uv = d.xz / (y + 0.25) * 1.6 + vec2(TIME * 0.006, TIME * 0.002);
		float c = fbm2(uv * 1.4);
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.08, c);
		float shade = smoothstep(0.0, 0.2, fbm2(uv * 1.4 + vec2(0.06, 0.05)) - c + 0.08);
		vec3 cc = mix(cloud_shadow.rgb, cloud_color.rgb, shade);
		col = mix(col, cc, cover * smoothstep(-0.05, 0.12, y) * 0.95);
	}
	if (AT_CUBEMAP_PASS && y > 0.0) {
		col = mix(col, cloud_color.rgb, 0.15);
	}

	// stars
	vec2 suv = d.xz / (abs(y) + 0.3) * 80.0;
	float st = step(0.996, h21(floor(suv))) * smoothstep(0.35, 0.9, y);
	st *= 0.6 + 0.4 * sin(TIME * 3.0 + h21(floor(suv) + 3.1) * 40.0);
	col += vec3(st) * star_amount;
	COLOR = col;
}
