// Cel-shading de gibi: faixas de luz, sombra com retícula (halftone), contorno
// de luz dourada do sol de fim de tarde, vento opcional e névoa de distância.
// Unshaded: fica igual em qualquer celular e custa pouco.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.45, 0.75, 1.0);
uniform float rim_amount = 0.35;
uniform float spec_amount = 0.0;
uniform float halftone = 1.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wind = 0.0;
uniform float fog = 1.0;

const vec3 KEY = vec3(-0.45, 0.72, 0.53);      // luz principal (frente-esquerda)
const vec3 SUN_BACK = vec3(-0.55, 0.35, -0.76); // sol baixo atrás da quadra (contraluz)
const vec3 HAZE = vec3(1.0, 0.84, 0.72);

void vertex() {
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y - 2.0, 0.0);
		VERTEX.x += sin(TIME * 1.6 + wp.x * 0.3 + wp.z * 0.2) * wind * h * 0.06;
		VERTEX.z += cos(TIME * 1.3 + wp.x * 0.2) * wind * h * 0.04;
	}
}

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb;
	vec3 L = normalize((VIEW_MATRIX * vec4(normalize(KEY), 0.0)).xyz);
	float ndl = dot(NORMAL, L);
	float lit = smoothstep(-0.02, 0.04, ndl);
	float hi = smoothstep(0.55, 0.6, ndl);
	vec3 shadow_col = base * shadow_tint.rgb;
	vec3 col = mix(shadow_col, base * mix(0.95, 1.07, hi) * vec3(1.03, 1.0, 0.95), lit);

	float px = max(VIEWPORT_SIZE.y / 720.0, 1.0) * 5.0;
	vec2 g = FRAGCOORD.xy / px;
	g = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * g;
	float d = length(fract(g) - 0.5);
	float amount = clamp((-0.04 - ndl) * 1.5, 0.0, 1.0) * halftone;
	float r = 0.48 * sqrt(amount);
	float dots = 1.0 - smoothstep(r - 0.08, r, d);
	col = mix(col, col * 0.74, dots * step(0.001, amount));

	// contorno de luz dourada (contraluz do sol baixo)
	vec3 S = normalize((VIEW_MATRIX * vec4(normalize(SUN_BACK), 0.0)).xyz);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = step(0.55, fres) * smoothstep(-0.1, 0.4, dot(NORMAL, S));
	col = mix(col, col * 0.6 + vec3(1.0, 0.82, 0.5) * 0.55, rim * rim_amount);

	vec3 H = normalize(L + VIEW);
	col += vec3(1.0) * step(0.965, dot(NORMAL, H)) * spec_amount;

	col = mix(col, flash_color.rgb, flash);
	float dist = length(VERTEX);
	col = mix(col, HAZE, smoothstep(45.0, 380.0, dist) * 0.85 * fog);
	ALBEDO = col;
}
