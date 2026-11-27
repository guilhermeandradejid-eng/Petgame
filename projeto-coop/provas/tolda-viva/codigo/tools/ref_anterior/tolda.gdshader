// Pano da tolda (empanada e bambinela) em chita, com pregas em 2 degraus e barra recortada em festão.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D chita : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 rep = vec2(10.0, 1.0);
uniform float pleats = 22.0;
uniform vec3 shade : source_color = vec3(0.62, 0.50, 0.64);
uniform bool scallop_bottom = true;
uniform bool scallop_top = false;
uniform vec3 trim : source_color = vec3(0.95, 0.76, 0.19);
void fragment() {
	vec2 uv = UV;
	float s = sin(uv.x * pleats * 6.2832);
	vec3 c = texture(chita, uv * rep + vec2(0.0, s * 0.01)).rgb;
	c *= mix(shade, vec3(1.0), step(-0.35, s));
	float sc = 0.035 * abs(sin(uv.x * pleats * 3.1416));
	float a = 1.0;
	if (scallop_bottom && uv.y > 0.93 - sc) { c = trim; if (uv.y > 0.97 - sc) a = 0.0; }
	if (scallop_top && uv.y < 0.07 + sc) { c = trim; if (uv.y < 0.03 + sc) a = 0.0; }
	ALBEDO = c;
	ALPHA = a; ALPHA_SCISSOR_THRESHOLD = 0.5;
}
