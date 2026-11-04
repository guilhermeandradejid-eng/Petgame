// Areia clara de desenho: manchas grandes e macias, quadra rastelada mais clara
// com borda nítida, faixa molhada e linha da onda na beira curva da praia.
shader_type spatial;
render_mode unshaded;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 sand : source_color = vec4(0.965, 0.867, 0.643, 1.0);        // #F6DDA4
uniform vec4 sand_dark : source_color = vec4(0.922, 0.776, 0.549, 1.0);   // #EBC68C
uniform vec4 sand_light : source_color = vec4(0.984, 0.91, 0.745, 1.0);   // #FBE8BE
uniform vec4 wet : source_color = vec4(0.851, 0.69, 0.494, 1.0);          // #D9B07E
uniform vec4 wet_edge : source_color = vec4(0.788, 0.604, 0.416, 1.0);    // #C99A6A
uniform vec2 court_half = vec2(4.0, 8.0);
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
	float line = shore_z + shore_off(wpos.x);
	if (wpos.z < line) {
		discard;   // depois da linha curva da praia é o mar
	}
	// areia seca com manchas grandes e macias (pintadas), sem riscos nem pontinhos
	float big = noise(p * 0.05) * 0.7 + noise(p * 0.13 + 4.0) * 0.3;
	vec3 col = mix(sand.rgb, sand_dark.rgb, smoothstep(0.45, 0.75, big) * 0.6);
	// quadra rastelada: retângulo mais claro e liso com borda nítida
	vec2 cq = abs(p) - (court_half + vec2(0.6));
	float court = 1.0 - smoothstep(0.0, 0.3, max(cq.x, cq.y));
	col = mix(col, sand_light.rgb, court * 0.85);
	// marcas leves do rastelo só dentro da quadra
	float rake = smoothstep(0.86, 0.94, fract(p.x * 1.6 + noise(p * 0.6) * 0.4)) * court;
	col = mix(col, sand.rgb, rake * 0.25);
	// faixa molhada perto do mar (4 m) e a linha escura da última onda
	float d = wpos.z - line;
	float wetness = 1.0 - smoothstep(2.5, 4.0, d);
	col = mix(col, wet.rgb, wetness);
	float edge = 1.0 - smoothstep(0.0, 0.08, abs(d - (4.0 + sin(wpos.x * 0.4) * 0.3)) - 0.06);
	col = mix(col, wet_edge.rgb, edge * 0.7);
	col = mix(col, vec3(0.98, 0.93, 0.86), smoothstep(45.0, 300.0, dist) * 0.6);
	ALBEDO = night_grade(col, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
