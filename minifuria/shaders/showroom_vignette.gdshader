shader_type canvas_item;
// Garagem: escurece as bordas (onde ficam os painéis) e deixa o centro livre para o carro na plataforma.
void fragment() {
	vec2 uv = UV;
	float side = smoothstep(0.42, 0.0, uv.x) * 0.55 + smoothstep(0.62, 1.0, uv.x) * 0.5;
	float bottom = smoothstep(0.7, 1.0, uv.y) * 0.55;
	float top = smoothstep(0.12, 0.0, uv.y) * 0.4;
	COLOR = vec4(0.03, 0.025, 0.06, clamp(side + bottom + top, 0.0, 0.8));
}
