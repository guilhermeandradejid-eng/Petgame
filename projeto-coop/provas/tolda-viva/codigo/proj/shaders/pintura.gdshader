// Telão, bastidores recortados e luas de papel: pintura sem sombra própria (é lona pintada), com
// recorte por alfa, leve toon no recorte (a madeira de trás) e tinta de luz da cena.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brilho = 1.0;
uniform bool recorte = false;
uniform vec3 verso : source_color = vec3(0.35, 0.27, 0.22);
void fragment() {
	vec4 t = texture(tex, UV);
	if (recorte && t.a < 0.5) discard;
	vec3 c = t.rgb * tint * brilho;
	if (!FRONT_FACING) c = verso;
	ALBEDO = c;
}
