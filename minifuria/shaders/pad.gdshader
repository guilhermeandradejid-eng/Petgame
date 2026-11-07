shader_type spatial;
render_mode cull_disabled;
// Placa de turbo: chapa escura com moldura, setas de luz correndo para a frente, LEDs nas laterais
// e uma onda branca quando alguém passa (hit 1 -> 0).
// UV.x = 0..1 na largura, UV.y = 0 (trás) .. 1 (frente)
uniform vec4 accent : source_color = vec4(1.0, 0.55, 0.1, 1.0);
uniform float hit = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float x = abs(uv.x - 0.5);
	float y = uv.y;
	// chapa: grade fina + leve variação
	vec2 g = fract(vec2(uv.x * 10.0, y * 6.0));
	float grid = smoothstep(0.06, 0.0, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)));
	vec3 panel = vec3(0.07, 0.075, 0.09) * (0.9 + hash(floor(vec2(uv.x * 10.0, y * 6.0))) * 0.2);
	panel *= 1.0 - grid * 0.35;
	// moldura metálica com faixas zebradas
	float frame = max(step(0.43, x), max(step(0.95, y), step(y, 0.05)));
	float zebra = step(0.5, fract((uv.x + y) * 6.0));
	vec3 frame_col = mix(vec3(0.16, 0.16, 0.18), accent.rgb * 0.55, zebra);
	// setas (chevrons) correndo para a frente
	float yy = fract(y * 3.0 - TIME * 2.6);
	float d = yy + x * 0.95;   // seta em "V" com a ponta para a frente
	float chev = smoothstep(0.06, 0.0, abs(d - 0.6) - 0.07) * step(x, 0.4);
	float lead = smoothstep(0.035, 0.0, abs(d - 0.67)) * step(x, 0.4);
	// LEDs laterais acendendo em sequência
	float led_cell = fract(y * 9.0 - TIME * 4.0);
	float led = step(led_cell, 0.35) * step(0.445, x) * step(x, 0.485) * step(0.07, y) * step(y, 0.93);
	// onda do "hit": varre a placa de trás para frente
	float wave_pos = 1.0 - hit;
	float wave = smoothstep(0.14, 0.0, abs(y - wave_pos)) * hit;
	vec3 col = mix(panel, frame_col, frame);
	col = mix(col, accent.rgb * 0.35, chev);
	ALBEDO = col;
	vec3 em = accent.rgb * chev * 2.4 + vec3(1.0, 0.96, 0.85) * lead * 2.2 + accent.rgb * led * 3.0;
	em += (mix(accent.rgb, vec3(1.0), 0.6) * wave * 2.2 + accent.rgb * hit * 0.5) * (1.0 - frame * 0.5);
	// brilho suave constante para a placa "respirar"
	em += accent.rgb * 0.12 * (0.6 + 0.4 * sin(TIME * 5.0)) * (1.0 - frame);
	EMISSION = em;
	ROUGHNESS = mix(0.35, 0.55, frame);
	METALLIC = mix(0.5, 0.7, frame);
}
