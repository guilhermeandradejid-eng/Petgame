// Ondas de impacto no chão em traço de pena: 2 ou 3 anéis concêntricos que abrem com desaceleração, afinam no fim
// do traço (taper), são quebrados por ruído e somem com o tempo (0,4 s) e a distância. Cor do papel em grão (alfa).
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform vec3 cor : source_color = vec3(0.914, 0.875, 0.788);
uniform vec3 cor2 : source_color = vec3(0.137, 0.110, 0.090);
uniform float k = 0.0;          // 0..1 do tempo de vida
uniform int aneis = 3;
uniform float largura = 0.05;   // fração do raio
uniform float semente = 0.0;
uniform float alfa = 1.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	float d = dot(VERTEX.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x);
	float a = 0.0;
	float tinta = 0.0;
	for (int i = 0; i < 3; i++) {
		if (i >= aneis) break;
		float ki = clamp((k - float(i) * 0.12) / (1.0 - float(i) * 0.12), 0.0, 1.0);
		if (ki <= 0.0) continue;
		float ri = (1.0 - pow(1.0 - ki, 3.0)) * (1.0 - float(i) * 0.22);
		// traço de pena: cada anel é feito de 3 a 4 arcos; cada arco afina nas duas pontas
		float narc = 3.0 + float(i);
		float u = fract(ang / 6.2832 * narc + h21(vec2(float(i), semente)));
		float taper = smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.55, u);
		float quebra = step(0.35, vn(vec2(ang * 4.0 + float(i) * 7.0, semente + float(i))));
		float w = largura * (1.0 - ki * 0.7) * taper * (1.0 - float(i) * 0.25);
		float lin = 1.0 - smoothstep(w * 0.5, w, abs(r - ri));
		float vida = 1.0 - smoothstep(0.55, 1.0, ki);
		a = max(a, lin * quebra * vida);
		tinta = max(tinta, (1.0 - smoothstep(w * 0.25, w * 0.45, abs(r - ri + w * 1.1))) * quebra * vida * step(0.03, w) * 0.0);
	}
	a *= alfa * smoothstep(1.0, 0.85, r);
	tinta *= alfa * smoothstep(1.0, 0.85, r) * 0.9;
	float g = texture(grao, FRAGCOORD.xy / 256.0).r * 0.996 + 0.002;
	if (g < a) { ALBEDO = cor; }
	else if (g < tinta) { ALBEDO = cor2; }
	else { discard; }
}
