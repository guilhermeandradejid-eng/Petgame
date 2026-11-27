// Papel impresso em xilogravura. Mapas gerados por script: R = tinta, G = cor 1, B = cor 2, A = recorte.
// Tudo no material (nada de filtro de tela): fibra do papel, pressão da tinta e registro deslocado da cor.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D xilo : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 paper : source_color = vec3(0.929, 0.890, 0.796);
uniform vec3 ink : source_color = vec3(0.118, 0.102, 0.110);
uniform vec3 spot1 : source_color = vec3(0.85, 0.64, 0.26);
uniform vec3 spot2 : source_color = vec3(0.49, 0.55, 0.35);
uniform float spot1_amt = 1.0;
uniform float spot2_amt = 1.0;
uniform vec2 reg = vec2(0.0012, -0.0016);
uniform vec2 fiber_scale = vec2(900.0, 500.0);
uniform bool cutout = false;
uniform vec3 id_color : source_color = vec3(0.0);
uniform bool id_mode = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec4 t = texture(xilo, UV);
	vec4 ts = texture(xilo, UV + reg);
	float fib = vn(UV * fiber_scale) * 0.6 + vn(UV * fiber_scale * vec2(3.1, 0.4)) * 0.4;
	vec3 c = paper * (0.97 + 0.06 * fib);
	c = mix(c, spot1 * (0.97 + 0.05 * fib), ts.g * spot1_amt);
	c = mix(c, spot2 * (0.97 + 0.05 * fib), ts.b * spot2_amt);
	float press = 0.88 + 0.12 * smoothstep(0.25, 0.75, vn(UV * fiber_scale * 0.35));
	c = mix(c, ink, t.r * press);
	ALBEDO = id_mode ? id_color : c;
	if (cutout) { ALPHA = t.a; ALPHA_SCISSOR_THRESHOLD = 0.5; }
}
