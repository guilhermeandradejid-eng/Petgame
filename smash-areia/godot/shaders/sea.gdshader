shader_type spatial;
render_mode unshaded;

uniform vec4 deep : source_color = vec4(0.07, 0.5, 0.85, 1.0);
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
	// brilho do sol
	float g = step(0.985, sin(wpos.x * 1.7 + TIME * 2.0) * sin(wpos.z * 1.3 - TIME));
	col = mix(col, vec3(1.0), g * 0.7 * smoothstep(6.0, 30.0, dist));
	ALBEDO = col;
}
