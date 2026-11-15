// Marcas no chao: avisos de ataque (disco/setor/linha que enche), aneis de impacto e circulos de runa.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float progress = 0.0;
uniform float angle = 6.2832;
uniform int mode = 0;   // 0 aviso disco/setor, 1 anel que expande, 2 linha, 3 brilho suave, 4 circulo de runas
uniform float fade = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	if (mode == 0) {
		float ang = abs(atan(p.x, -p.y));
		float half_a = angle * 0.5;
		float in_sector = smoothstep(half_a, half_a - 0.03, ang);
		float disc = smoothstep(1.0, 0.975, r);
		float edge = smoothstep(0.91, 0.955, r) * disc;
		float side = smoothstep(0.06, 0.0, abs(ang - half_a) * r) * step(angle, 6.2) * disc;
		float fill = step(r, progress) * 0.42 + 0.14;
		float prog_edge = smoothstep(0.045, 0.0, abs(r - progress)) * 0.55;
		a = disc * in_sector * (fill + prog_edge) + edge * in_sector + side * 0.8;
	} else if (mode == 1) {
		float w = 0.16;
		float rr = progress * (1.0 - w * 0.5);
		a = smoothstep(w, 0.0, abs(r - rr)) * (1.0 - progress);
		a += smoothstep(rr, rr - 0.6, r) * step(r, rr) * 0.14 * (1.0 - progress);
	} else if (mode == 2) {
		vec2 q = abs(p);
		float edge = max(smoothstep(0.86, 0.96, q.x), smoothstep(0.975, 0.995, q.y));
		float fill = step(1.0 - UV.y, progress) * 0.4 + 0.14;
		a = fill + edge * 0.8;
	} else if (mode == 3) {
		a = smoothstep(1.0, 0.0, r);
		a *= a;
	} else {
		float ang = atan(p.y, p.x) + TIME * 0.4;
		float ring1 = smoothstep(0.03, 0.0, abs(r - 0.95));
		float ring2 = smoothstep(0.02, 0.0, abs(r - 0.76));
		float ticks = step(0.5, fract(ang * 14.0 / 6.2832)) * step(0.76, r) * step(r, 0.95) * 0.35;
		float star = smoothstep(0.03, 0.0, abs(r - 0.42 - 0.06 * sin(ang * 5.0 - TIME))) * 0.6;
		float glow = smoothstep(1.0, 0.1, r) * 0.16;
		a = (ring1 + ring2 + ticks + star + glow) * step(r, 1.0);
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * color.a * fade;
}
