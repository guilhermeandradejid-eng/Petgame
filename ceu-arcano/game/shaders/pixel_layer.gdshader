shader_type canvas_item;
// Camadas de cenário: filtro pixel AA + clarão de relâmpago.

uniform float flash = 0.0;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = UV * size;
	vec2 seam = floor(px + 0.5);
	vec2 fw = max(fwidth(px), vec2(1e-4));
	px = seam + clamp((px - seam) / fw, -0.5, 0.5);
	vec4 c = texture(TEXTURE, px / size);
	c.rgb = mix(c.rgb, vec3(0.85, 0.95, 1.0), flash * 0.45 * c.a);
	COLOR = c * COLOR;
}
