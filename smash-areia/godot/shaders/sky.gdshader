shader_type sky;

uniform vec4 top : source_color = vec4(0.18, 0.55, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(0.62, 0.92, 1.0, 1.0);
uniform vec4 bottom : source_color = vec4(0.96, 0.92, 0.75, 1.0);
uniform vec3 sun_dir = vec3(0.35, 0.32, -0.88);

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon.rgb, top.rgb, smoothstep(0.0, 0.55, y));
	col = mix(bottom.rgb, col, smoothstep(-0.08, 0.04, y));
	// raios de sol estilo gibi
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	vec3 side = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(side, s);
	float ang = atan(dot(EYEDIR, up), dot(EYEDIR, side));
	float rays = step(0.0, sin(ang * 14.0 + TIME * 0.15)) * smoothstep(0.8, 0.97, d) * 0.18;
	col = mix(col, vec3(1.0, 0.97, 0.75), rays);
	col = mix(col, vec3(1.0, 0.95, 0.6), smoothstep(0.988, 0.99, d));
	col = mix(col, vec3(1.0, 1.0, 0.92), smoothstep(0.994, 0.996, d));
	COLOR = col;
}
