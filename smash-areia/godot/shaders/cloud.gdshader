// Nuvem de gibi: topo branco, base lilás/rosada, borda dourada contra o sol baixo
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 lit : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 shade : source_color = vec4(0.82, 0.8, 0.98, 1.0);
uniform vec4 belly : source_color = vec4(1.0, 0.76, 0.78, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.84, 0.5, 1.0);
uniform vec3 sun_dir = vec3(-0.55, 0.2, -0.81);
uniform float haze = 0.0;
uniform vec4 haze_col : source_color = vec4(1.0, 0.86, 0.75, 1.0);

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wn);
	float up = n.y;
	float sun = dot(n, normalize(sun_dir));
	// duas faixas de luz (cel) e a barriga rosada
	vec3 c = mix(shade.rgb, lit.rgb, step(0.05, up * 0.8 + sun * 0.35));
	c = mix(c, belly.rgb, step(up, -0.45) * 0.85);
	// borda: fresnel em faixa dura, mais forte do lado do sol
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = step(0.72, fres) * (0.55 + 0.45 * clamp(sun * 0.5 + 0.5, 0.0, 1.0));
	c = mix(c, rim_col.rgb, rim);
	c = mix(c, haze_col.rgb, haze);
	ALBEDO = c;
}
