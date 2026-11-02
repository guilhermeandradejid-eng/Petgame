// Céu de fim de tarde com sol baixo, raios de gibi e faixas de nuvem
shader_type sky;

uniform vec4 top : source_color = vec4(0.22, 0.45, 0.92, 1.0);
uniform vec4 mid : source_color = vec4(0.55, 0.72, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.8, 0.62, 1.0);
uniform vec4 bottom : source_color = vec4(1.0, 0.86, 0.72, 1.0);
uniform vec3 sun_dir = vec3(-0.55, 0.2, -0.81);

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon.rgb, mid.rgb, smoothstep(0.0, 0.22, y));
	col = mix(col, top.rgb, smoothstep(0.2, 0.75, y));
	col = mix(bottom.rgb, col, smoothstep(-0.05, 0.02, y));
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	// brilho quente em volta do sol
	col = mix(col, vec3(1.0, 0.75, 0.45), smoothstep(0.7, 1.0, d) * 0.55 * smoothstep(-0.1, 0.3, y + 0.2));
	vec3 side = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(side, s);
	float ang = atan(dot(EYEDIR, up), dot(EYEDIR, side));
	float rays = step(0.0, sin(ang * 12.0 + TIME * 0.12)) * smoothstep(0.86, 0.975, d) * 0.07;
	col = mix(col, vec3(1.0, 0.92, 0.65), rays);
	col = mix(col, vec3(1.0, 0.86, 0.45), smoothstep(0.9915, 0.993, d));
	col = mix(col, vec3(1.0, 0.98, 0.85), smoothstep(0.9965, 0.9975, d));
	COLOR = col;
}
