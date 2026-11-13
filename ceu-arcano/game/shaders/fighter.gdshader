shader_type canvas_item;
// Pixel art nítido em qualquer zoom (filtro "pixel AA") + flash de impacto e tinta.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = UV * size;
	vec2 seam = floor(px + 0.5);
	vec2 fw = max(fwidth(px), vec2(1e-4));
	px = seam + clamp((px - seam) / fw, -0.5, 0.5);
	vec4 c = texture(TEXTURE, px / size);
	c.rgb *= tint.rgb;
	c.rgb = mix(c.rgb, flash_color.rgb, flash * step(0.01, c.a));
	COLOR = c * COLOR;
}
