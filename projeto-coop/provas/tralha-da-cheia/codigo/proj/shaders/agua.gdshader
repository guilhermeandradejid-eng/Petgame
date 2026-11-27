// Água em faixa pintada (regra 5): 3 tons chapados, sombra recortada sob o trapiche, traços claros de marola
// que andam em degrau (não há reflexo nem transparência). Recebe a sombra real no nível PC.
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 claro : source_color = vec3(0.612, 0.753, 0.714);
uniform vec3 medio : source_color = vec3(0.373, 0.557, 0.549);
uniform vec3 escuro : source_color = vec3(0.227, 0.361, 0.4);
uniform vec3 shadow_tint : source_color = vec3(0.56, 0.50, 0.70);
uniform float z_frente = 2.8;
uniform float z_fundo = -2.7;
uniform float t_q = 0.0;          // tempo em degrau (3 poses por segundo)
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 c = medio;
	// faixa escura recortada junto do trapiche (sombra pintada)
	float wav = 0.12 * sin(p.x * 2.3 + floor(t_q) * 1.7) + 0.06 * sin(p.x * 5.1);
	float dF = p.y - z_frente;
	float dB = z_fundo - p.y;
	float near_f = step(0.0, dF) * step(dF, 0.75 + wav);
	float near_b = step(0.0, dB) * step(dB, 0.9 + wav);
	c = mix(c, escuro, max(near_f, near_b));
	// linha clara de espuma logo depois da faixa escura
	float foam = step(0.0, dF - 0.75 - wav) * step(dF - 0.75 - wav, 0.07) + step(0.0, dB - 0.9 - wav) * step(dB - 0.9 - wav, 0.07);
	c = mix(c, claro, clamp(foam, 0.0, 1.0));
	// traços de marola: tracinhos pontudos em células, que mudam de lugar em degrau
	vec2 cs = vec2(1.7, 0.42);
	vec2 q = p / cs;
	q.x += floor(t_q) * 0.13 + 0.5 * floor(q.y);
	vec2 ci = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash(ci + floor(t_q * 0.34) * 0.0);
	float len = 0.25 + 0.2 * hash(ci + 3.1);
	float th = 0.10 * (1.0 - pow(abs(f.x) / len, 2.0));
	float dash = step(abs(f.x), len) * step(abs(f.y + 0.1 * (hash(ci + 7.3) - 0.5)), th) * step(0.42, h);
	float far = smoothstep(-6.0, -12.0, p.y);
	c = mix(c, claro, dash * (1.0 - max(near_f, near_b)));
	c = mix(c, mix(medio, claro, 0.45), far * 0.6);
	ALBEDO = c;
}
void light() {
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), ATTENUATION) * LIGHT_COLOR / PI;
}
