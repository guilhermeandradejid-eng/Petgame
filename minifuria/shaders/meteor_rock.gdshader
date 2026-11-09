shader_type spatial;
// Rocha do meteoro: basalto escuro com rachaduras de lava acesas (células de voronoi no espaço do objeto),
// mais quentes na frente (lado que desce) e pulsando.
uniform float heat = 1.0;
uniform vec3 lava : source_color = vec3(1.0, 0.42, 0.06);
varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
// distância à borda da célula mais próxima (F2 - F1)
float cells(vec3 p) {
	vec3 b = floor(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 r = g + h3(b + g) - fract(p);
		float d = dot(r, r);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return sqrt(f2) - sqrt(f1);
}

void fragment() {
	float e = cells(opos * 1.6);
	float crack = smoothstep(0.16, 0.02, e);
	float fine = smoothstep(0.08, 0.0, cells(opos * 4.2 + 3.0)) * 0.5;
	float pulse = 0.75 + 0.25 * sin(TIME * 7.0 + opos.y * 3.0);
	vec3 rock = mix(vec3(0.07, 0.06, 0.06), vec3(0.19, 0.15, 0.13), smoothstep(0.1, 0.5, e));
	ALBEDO = rock;
	ROUGHNESS = 0.92;
	EMISSION = lava * (crack + fine) * heat * pulse * 3.2 + lava * 0.15 * heat;
}
