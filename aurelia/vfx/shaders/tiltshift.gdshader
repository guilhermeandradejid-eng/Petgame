// HD-2D post pass: tilt-shift blur, soft vignette, chromatic pulse on big hits.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur : hint_range(0.0, 8.0) = 1.3;
uniform float focus_band = 0.22;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float chroma : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float off = max(abs(uv.y - 0.55) - focus_band, 0.0);
	float r = off * blur * 7.0;
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	for (int i = -3; i <= 3; i++) {
		float w = 1.0 - abs(float(i)) / 4.0;
		vec2 o = vec2(0.0, float(i)) * px * r * 0.5;
		vec2 dir = (uv - vec2(0.5));
		vec2 ca = dir * chroma * 0.02;
		col.r += texture(screen_tex, uv + o + ca).r * w;
		col.g += texture(screen_tex, uv + o).g * w;
		col.b += texture(screen_tex, uv + o - ca).b * w;
		wsum += w;
	}
	col /= wsum;
	float v = smoothstep(0.95, 0.35, length((uv - vec2(0.5)) * vec2(1.1, 1.0)));
	col *= mix(1.0 - vignette, 1.0, v);
	col = mix(col, flash_color.rgb, flash * 0.35);
	COLOR = vec4(col, 1.0);
}
