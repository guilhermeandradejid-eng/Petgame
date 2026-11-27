// v2: vinheta leve de VALOR (escurece as bordas para uma tinta violeta, sem mudar o matiz do centro).
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float forca = 0.22;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	vec2 p = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.32, 0.78, length(p));
	COLOR = vec4(mix(c, c * vec3(0.62, 0.56, 0.7), v * forca / 0.22 * 0.6), 1.0);
}
