shader_type spatial;
render_mode unshaded;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.1, 0.45, 0.82, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.85, 0.92, 1.0);
uniform vec4 foam : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shore_z = -24.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.15 + TIME * 1.2) * 0.12 * smoothstep(shore_z, shore_z - 10.0, wpos.z);
}

void fragment() {
	float dist = shore_z - wpos.z;
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(2.0, 40.0, dist));
	// faixas de ondas de desenho animado
	float w = sin(wpos.z * 0.45 + sin(wpos.x * 0.12 + TIME * 0.6) * 1.6 + TIME * 1.4);
	col = mix(col, col * 1.18 + vec3(0.04), step(0.93, w) * smoothstep(80.0, 5.0, dist));
	// espuma na beira
	float edge = sin(TIME * 1.3) * 0.9;
	float f = step(dist, 1.6 + edge + sin(wpos.x * 0.4 + TIME) * 0.4);
	col = mix(col, foam.rgb, f);
	// caminho de brilho do sol (fim de tarde, sol à esquerda)
	float path = smoothstep(90.0, 0.0, abs(wpos.x + (shore_z - wpos.z) * 0.68));
	float g = step(0.9 - path * 0.12, sin(wpos.x * 1.7 + TIME * 2.0) * sin(wpos.z * 1.3 - TIME));
	col = mix(col, vec3(1.0, 0.93, 0.75), g * (0.35 + path * 0.6) * smoothstep(6.0, 30.0, dist));
	col = mix(col, vec3(1.0, 0.75, 0.55), path * 0.18 * smoothstep(40.0, 300.0, dist));
	float vd = length(VERTEX);
	col = mix(col, vec3(1.0, 0.84, 0.72), smoothstep(80.0, 420.0, vd) * 0.8);
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
