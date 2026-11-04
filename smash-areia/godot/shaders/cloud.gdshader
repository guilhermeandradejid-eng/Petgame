// Nuvem de algodão: topo branco, sombra azul-clara, barriga reta azulada
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 lit : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade : source_color = vec4(0.843, 0.91, 1.0, 1.0);    // #D7E8FF
uniform vec4 belly : source_color = vec4(0.749, 0.847, 0.98, 1.0);   // #BFD8FA
uniform vec4 rim_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 sun_dir = vec3(-0.75, 0.32, -0.58);
uniform float haze = 0.0;
uniform vec4 haze_col : source_color = vec4(0.86, 0.94, 1.0, 1.0);

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wn);
	float up = n.y;
	float sun = dot(n, normalize(sun_dir));
	// duas faixas de luz (cel) e a barriga rosada
	vec3 c = mix(shade.rgb, lit.rgb, smoothstep(-0.05, 0.15, up * 0.8 + sun * 0.35));   // algodão macio
	c = mix(c, belly.rgb, step(up, -0.2));
	// borda: fresnel em faixa dura, mais forte do lado do sol
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.85, fres) * (0.55 + 0.45 * clamp(sun * 0.5 + 0.5, 0.0, 1.0));
	c = mix(c, rim_col.rgb, rim * 0.3);
	c = mix(c, haze_col.rgb, haze);
	ALBEDO = night_grade(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
