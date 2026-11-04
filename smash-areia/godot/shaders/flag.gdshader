// Flâmula balançando ao vento
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 color_a : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 5.0 + k * 6.0 + phase) * 0.18 * k;
	VERTEX.y += sin(TIME * 3.0 + k * 4.0 + phase) * 0.05 * k;
}

void fragment() {
	// flâmula triangular na cor do time com uma faixa clara perto do mastro
	// (listras horizontais pareciam bandeira de país)
	if (abs(UV.y - 0.5) > 0.5 * (1.0 - UV.x) + 0.02) {
		discard;
	}
	vec3 col = mix(color_a.rgb, color_b.rgb, step(UV.x, 0.12) * step(0.04, UV.x));
	float shade = 0.85 + 0.15 * sin(TIME * 5.0 + UV.x * 6.0 + phase);
	ALBEDO = night_grade(col * shade, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
