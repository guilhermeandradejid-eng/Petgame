// Onda de choque de gibi: anel que abre rápido + traços de velocidade radiais
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float t = 1.0;
uniform float seed = 0.0;
uniform float lines = 1.0;

void vertex() {
	// billboard que mantém a escala do nó
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float e = 1.0 - pow(1.0 - t, 3.0);          // abre rápido e desacelera
	float rad = mix(0.12, 0.92, e);
	float w = mix(0.16, 0.012, e);
	float ring = smoothstep(rad - w - 0.02, rad - w, r) * (1.0 - smoothstep(rad, rad + 0.02, r));
	// traços radiais (12 setores com comprimento sorteado)
	float sector = floor((a + 3.14159) / 6.28318 * 12.0);
	float h = hash(sector + seed * 7.0);
	float ang_c = (sector + 0.5) / 12.0 * 6.28318 - 3.14159;
	float da = abs(fract((a - ang_c) / 6.28318 + 0.5) - 0.5) * 6.28318;
	float thin = 1.0 - smoothstep(0.0, 0.05 * (1.0 - e * 0.6), da * r);
	float l0 = mix(0.3, 0.75, e) + h * 0.1;
	float l1 = l0 + (0.18 + 0.2 * h) * (1.0 - e);
	float streak = thin * smoothstep(l0, l0 + 0.03, r) * (1.0 - smoothstep(l1, l1 + 0.03, r)) * step(0.35, h) * lines;
	float m = max(ring, streak);
	vec3 col = mix(color.rgb, vec3(1.0), 0.45 * (1.0 - e));
	ALBEDO = col;
	ALPHA = m * (1.0 - smoothstep(0.55, 1.0, t)) * color.a;
}
