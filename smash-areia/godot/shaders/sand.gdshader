// Areia de gibi: quadra rastelada e lisa, ondulações de vento com crista clara
// e sombra em retícula fora dela, conchinhas, brilho de grãos e beira molhada.
shader_type spatial;
render_mode unshaded;

uniform vec4 sand : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.93, 0.73, 0.47, 1.0);
uniform vec4 sand_light : source_color = vec4(1.0, 0.93, 0.74, 1.0);
uniform vec4 wet : source_color = vec4(0.82, 0.66, 0.45, 1.0);
uniform float shore_z = -24.0;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float n = noise(p * 0.35) * 0.6 + noise(p * 1.3) * 0.4;
	vec3 col = mix(sand.rgb, sand_dark.rgb, smoothstep(0.55, 0.78, n) * 0.3);
	// quadra rastelada: mais clara e lisa, com marcas finas do rastelo
	vec2 cq = abs(p) - vec2(5.4, 9.6);
	float court = 1.0 - smoothstep(0.0, 1.6, max(cq.x, cq.y));
	float rake = smoothstep(0.82, 0.9, fract(p.x * 2.2 + noise(p * 0.6) * 0.6)) * 0.5;
	col = mix(col, mix(sand_light.rgb, sand.rgb, 0.35 + rake * 0.25), court * 0.55);
	// ondulações de vento (fora da quadra): crista clara + sombra com retícula
	vec2 w = vec2(p.x * 0.35 + p.y * 0.94, p.x * 0.94 - p.y * 0.35);
	float warp = noise(p * 0.12) * 3.0 + noise(p * 0.5) * 0.6;
	float ph = fract(w.x * 0.9 + warp);
	float crest = smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.1, 0.2, ph));
	float shade = smoothstep(0.2, 0.3, ph) * (1.0 - smoothstep(0.42, 0.55, ph));
	float ripples = (1.0 - court) * smoothstep(120.0, 20.0, dist) * (0.55 + 0.45 * noise(p * 0.08));
	vec2 sp = FRAGCOORD.xy / 5.0;
	float dots = step(length(fract(sp) - 0.5), 0.26);
	col = mix(col, sand_light.rgb, crest * ripples * 0.6);
	col = mix(col, sand_dark.rgb * 0.95, shade * ripples * mix(0.25, 0.5, dots));
	// grãos e conchinhas
	vec2 cell = floor(p * 9.0);
	float speck = step(0.93, hash(cell));
	col = mix(col, sand_dark.rgb * 0.92, speck * 0.22);
	vec2 sc = floor(p * 1.4);
	float shell = step(0.985, hash(sc + 3.1)) * step(length(fract(p * 1.4) - 0.5), 0.1) * (1.0 - court);
	col = mix(col, vec3(1.0, 0.82, 0.86), shell * 0.9);
	// brilho de grão que pisca perto da câmera
	float g = hash(floor(p * 22.0));
	float glint = step(0.996, g) * step(0.6, sin(TIME * 3.0 + g * 60.0)) * smoothstep(30.0, 6.0, dist);
	col = mix(col, vec3(1.0, 1.0, 0.95), glint);
	// beira do mar molhada com linha de espuma seca
	float wetness = smoothstep(shore_z + 6.0, shore_z + 1.5, wpos.z);
	col = mix(col, wet.rgb, wetness);
	float foam_line = smoothstep(0.0, 0.25, 1.0 - abs(wpos.z - (shore_z + 6.3 + sin(p.x * 0.3) * 0.6)) * 2.0);
	col = mix(col, sand_light.rgb, foam_line * 0.35);
	col *= vec3(1.02, 0.99, 0.95);
	col = mix(col, vec3(1.0, 0.84, 0.72), smoothstep(45.0, 300.0, dist) * 0.7);
	ALBEDO = col;
}
