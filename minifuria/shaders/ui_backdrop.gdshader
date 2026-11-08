shader_type canvas_item;
// Fundo dos menus: tinta escura à esquerda (navegação) que abre para a pista em movimento à direita,
// com linhas de velocidade diagonais correndo e um brilho âmbar no canto.
uniform float dim = 0.85;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.11, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.7, 0.1, 1.0);

float hash(float n) { return fract(sin(n * 91.345) * 47453.21); }

void fragment() {
	vec2 uv = UV;
	float aspect = 1.0 / SCREEN_PIXEL_SIZE.x * SCREEN_PIXEL_SIZE.y;
	// escurecimento: forte à esquerda, suave à direita
	float d = mix(dim, dim * 0.35, smoothstep(0.25, 0.85, uv.x));
	vec3 col = ink.rgb;
	float a = d;
	// linhas de velocidade (diagonais, inclinadas como os botões)
	vec2 p = vec2(uv.x + uv.y * 0.22, uv.y);
	float row = floor(p.y * 46.0);
	float speed = 0.35 + hash(row) * 0.9;
	float len = 0.08 + hash(row + 3.1) * 0.22;
	float x = fract(p.x * 0.9 - TIME * speed * 0.35 + hash(row + 7.7));
	float line = smoothstep(0.0, 0.02, x) * smoothstep(len, len - 0.06, x);
	float thin = smoothstep(0.5, 0.15, abs(fract(p.y * 46.0) - 0.5));
	float show = step(0.62, hash(row + 1.3));
	float sl = line * thin * show * (0.07 + 0.08 * hash(row + 9.0)) * smoothstep(1.0, 0.3, uv.x);
	col += vec3(1.0) * sl;
	a = clamp(a + sl, 0.0, 1.0);
	// brilho âmbar no canto inferior esquerdo
	float g = smoothstep(0.9, 0.0, length((uv - vec2(-0.05, 1.05)) * vec2(1.0, 1.6)));
	col += hot.rgb * g * 0.18;
	COLOR = vec4(col, a);
}
