// Partículas de oficina num só desenho (ImmediateMesh): serragem, maravalha, gotas de tinta, poeira,
// confete. UV2.x = semente, UV2.y = índice da cor na paleta, UV2 passa também a forma (inteiro).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 pal[8] : source_color;
uniform vec3 tinta : source_color = vec3(0.114, 0.094, 0.125);
varying vec2 info;
float h(vec2 p, float s) { return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.0) * 43758.5453); }
void vertex() { info = UV2; }
void fragment() {
	float sem = fract(info.x);
	int forma = int(floor(info.x));
	int ci = int(info.y + 0.5);
	vec3 c = pal[ci];
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x); float r = length(p);
	float e;
	if (forma == 0) { e = 0.5 + 0.45 * h(vec2(floor((a + 3.2) * 0.95), 1.0), sem); }   // lasca de serragem
	else if (forma == 1) { e = 0.86 + 0.07 * sin(a * 3.0 + sem * 40.0); }               // gota de tinta
	else if (forma == 2) { e = 0.62 + 0.22 * sin(a * 3.0 + sem * 30.0) + 0.1 * sin(a * 7.0); } // poeira
	else { e = max(abs(p.x), abs(p.y)) < 0.9 ? 2.0 : 0.0; r = 0.0; }                    // confete
	if (r > e) discard;
	if (forma == 2) {
		ALBEDO = c * (0.9 + 0.1 * h(floor(UV * 6.0), sem));
	} else {
		ALBEDO = mix(c, tinta, step(e - (forma == 0 ? 0.12 : 0.16), r) * (forma == 3 ? 0.0 : 1.0));
	}
}
