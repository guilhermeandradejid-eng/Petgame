// Mar de desenho: três tons de água, risquinhos de onda e espuma em festão
// na linha curva da praia (shore_off, compartilhada com a areia).
shader_type spatial;
render_mode unshaded;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.118, 0.451, 0.784, 1.0);       // #1E73C8
uniform vec4 mid_water : source_color = vec4(0.133, 0.722, 0.847, 1.0);  // #22B8D8
uniform vec4 shallow : source_color = vec4(0.373, 0.878, 0.824, 1.0);    // #5FE0D2
uniform vec4 far_haze : source_color = vec4(0.604, 0.839, 0.949, 1.0);   // #9AD6F2
uniform vec4 foam : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shore_z = -24.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.15 + TIME * 1.2) * 0.12 * smoothstep(shore_z, shore_z - 10.0, wpos.z);
}

float hash1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// distância até a linha da praia (curva, igual à da areia)
	float line = shore_z + shore_off(wpos.x);
	float dist = line - wpos.z;
	float vd = length(VERTEX);
	// degradê em três águas: rasa (0-6 m), média (6-25 m) e funda, com névoa longe
	vec3 col = mix(shallow.rgb, mid_water.rgb, smoothstep(0.0, 6.0, dist));
	col = mix(col, deep.rgb, smoothstep(6.0, 25.0, dist));
	col = mix(col, far_haze.rgb, smoothstep(150.0, 420.0, vd) * 0.85);
	// "risquinhos" de onda de desenho (cápsulas brancas espalhadas, andando para a praia)
	vec2 q = vec2(wpos.x, wpos.z + TIME * 0.4);
	vec2 cell = floor(q / vec2(6.0, 2.5));
	float h = hash1(cell);
	vec2 c = (cell + vec2(0.5) + (vec2(hash1(cell + 3.1), hash1(cell + 7.3)) - 0.5) * 0.5) * vec2(6.0, 2.5);
	vec2 dq = q - c;
	float cap = length(vec2(max(abs(dq.x) - 1.1, 0.0), dq.y)) - 0.125;
	float dash = step(0.85, h) * (1.0 - smoothstep(-0.02, 0.02, cap)) * (1.0 - smoothstep(25.0, 80.0, dist))
		* smoothstep(2.5, 5.0, dist);
	col = mix(col, foam.rgb, dash * 0.6);
	// espuma: faixa principal com borda em festão que vai e volta (4 s) e uma linha fina mais para fora
	float sweep = sin(TIME * 1.5708) * 1.2;
	float scallop = (sin(wpos.x * 0.9) + 0.3 * sin(wpos.x * 2.3 + 1.0)) * 0.18;
	float band = step(dist, 0.8 + sweep + scallop);
	col = mix(col, foam.rgb, band);
	float sweep2 = sin(TIME * 1.5708 - 1.5708) * 1.0;
	float thin = 1.0 - smoothstep(0.0, 0.08, abs(dist - (3.0 + sweep2 + scallop * 0.6)) - 0.075);
	col = mix(col, foam.rgb, thin * 0.85);
	float f = band;
	if (arena_night > 0.001) {
		// noite: mar escuro com o caminho prateado da lua (lua à direita, alta)
		vec3 ncol = mix(vec3(0.05, 0.16, 0.3), vec3(0.02, 0.05, 0.14), smoothstep(2.0, 60.0, dist));
		ncol = mix(ncol, vec3(0.75, 0.85, 1.0), f * 0.55);
		float mpath = smoothstep(32.0, 0.0, abs(wpos.x - (shore_z - wpos.z) * 0.45));
		float mg = step(0.93 - mpath * 0.08, sin(wpos.x * 1.9 + TIME * 1.6) * sin(wpos.z * 1.1 - TIME * 0.8));
		ncol = mix(ncol, vec3(0.85, 0.9, 1.0), mg * mpath * mpath * smoothstep(6.0, 40.0, dist) * 0.7);
		ncol = mix(ncol, vec3(0.2, 0.28, 0.5), mpath * 0.25 * smoothstep(30.0, 200.0, dist));
		ncol = mix(ncol, vec3(0.05, 0.07, 0.18), smoothstep(120.0, 420.0, vd) * 0.8);
		col = mix(col, ncol, arena_night);
	}
	ALBEDO = col;
}
