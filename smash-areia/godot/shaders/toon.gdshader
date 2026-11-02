// Cel-shading de gibi: 3 faixas de luz, sombra com retícula (halftone),
// brilho de borda e um "risco" de especular. Iluminação fixa e unshaded
// para ficar igual em qualquer celular e custar pouco.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.52, 0.42, 0.72, 1.0);
uniform float rim_amount = 0.35;
uniform float spec_amount = 0.0;
uniform float halftone = 1.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 SUN = vec3(0.42, 0.78, 0.46);

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb;
	vec3 L = normalize((VIEW_MATRIX * vec4(normalize(SUN), 0.0)).xyz);
	float ndl = dot(NORMAL, L);
	float lit = smoothstep(-0.02, 0.04, ndl);
	float hi = smoothstep(0.55, 0.6, ndl);
	vec3 shadow_col = base * shadow_tint.rgb;
	vec3 col = mix(shadow_col, base * mix(0.92, 1.06, hi), lit);

	// retícula de pontinhos nas áreas de sombra (estilo impressão de gibi)
	float px = max(VIEWPORT_SIZE.y / 720.0, 1.0) * 5.0;
	vec2 g = FRAGCOORD.xy / px;
	g = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * g;
	float d = length(fract(g) - 0.5);
	float amount = clamp((-0.04 - ndl) * 1.5, 0.0, 1.0) * halftone;
	float r = 0.48 * sqrt(amount);
	float dots = 1.0 - smoothstep(r - 0.08, r, d);
	col = mix(col, col * 0.72, dots * step(0.001, amount));

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col += vec3(1.0, 0.96, 0.85) * step(0.45, rim) * rim_amount * lit * 0.5;

	vec3 H = normalize(L + VIEW);
	col += vec3(1.0) * step(0.965, dot(NORMAL, H)) * spec_amount;

	col = mix(col, flash_color.rgb, flash);
	ALBEDO = col;
}
