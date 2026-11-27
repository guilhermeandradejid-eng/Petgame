// Mar do cais pintado como painel: azul-noite com cristas de onda a pincel (traço com começo,
// corpo e fim) que rolam devagar. Sem degradê liso: só 3 valores.
shader_type spatial;
render_mode cull_back, unshaded;
uniform float time = 0.0;
uniform vec3 noite : source_color = vec3(0.114, 0.153, 0.333);
uniform vec3 medio : source_color = vec3(0.263, 0.388, 0.682);
uniform vec3 aguado : source_color = vec3(0.663, 0.733, 0.867);
uniform vec3 estanho : source_color = vec3(0.937, 0.914, 0.863);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 col = noite;
	float tq = floor(time * 8.0) / 8.0;      // ondas "fervendo" a 8 fps, como o traço pintado
	// faixas de corpo de onda (médio) e cristas (aguado + espuma em reserva)
	float row = p.y * 1.25 + p.x * 0.35;
	float id = floor(row);
	float f = fract(row);
	float ph = hash(vec2(id, 3.0)) * 6.28;
	float crest = 0.55 + 0.18 * sin(p.x * 1.4 + ph + tq * 0.9) + 0.06 * sin(p.x * 4.1 + ph * 2.0);
	float body = smoothstep(crest - 0.02, crest, f) * (1.0 - smoothstep(crest + 0.30, crest + 0.34, f));
	col = mix(col, medio, body * 0.85);
	// crista: traço que afina nas pontas (começo e fim de pincel)
	float seg = fract(p.x * 0.45 + hash(vec2(id, 7.0)) + tq * 0.04);
	float taper = smoothstep(0.0, 0.25, seg) * (1.0 - smoothstep(0.6, 0.95, seg));
	float d = abs(f - crest);
	float th = 0.035 * taper + 0.004;
	float line = 1.0 - smoothstep(th * 0.6, th, d + (vn(p * 30.0) - 0.5) * 0.01);
	col = mix(col, aguado, line);
	// espuma: dedos curtos sobre a crista
	float fo = step(0.82, vn(vec2(p.x * 6.0, id * 3.0 + tq))) * (1.0 - smoothstep(0.0, 0.02, abs(f - crest + 0.03)));
	col = mix(col, estanho, fo * taper);
	ALBEDO = col;
}
