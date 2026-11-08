shader_type spatial;
// Piso da vitrine: verniz escuro semitransparente (o carro espelhado aparece por baixo), plataforma giratória com
// anel de LEDs correndo e marcas radiais, e desvanece na cor do ciclorama ao longe (estúdio "sem fim").
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec3 base_col : source_color = vec3(0.035, 0.035, 0.05);
uniform vec3 far_col : source_color = vec3(0.055, 0.05, 0.1);
uniform vec3 accent : source_color = vec3(1.0, 0.7, 0.1);
uniform float table_r = 3.3;      // raio da plataforma
uniform float table_ang = 0.0;    // rotação da plataforma (as marcas giram junto)
uniform float refl = 0.24;        // quanto do carro espelhado aparece
uniform float pulse = 0.0;        // brilho extra (compra / troca de carro)

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = length(wp.xz);
	float a = atan(wp.z, wp.x) - table_ang;
	float inside = 1.0 - smoothstep(table_r - 0.02, table_r + 0.02, r);
	vec3 col = base_col;
	// plataforma: um pouco mais clara, com anéis finos e 24 marcas radiais
	col += vec3(0.025, 0.025, 0.035) * inside;
	float rings = smoothstep(0.012, 0.0, abs(fract(r * 1.6) - 0.5) - 0.48) * inside * 0.05;
	float ticks = smoothstep(0.03, 0.0, abs(fract(a / 6.2831853 * 24.0) - 0.5) - 0.47) * smoothstep(table_r - 0.45, table_r - 0.3, r) * inside;
	col += vec3(rings) + accent * ticks * 0.25;
	// anel de LEDs na borda da plataforma, com uma "onda" correndo
	float ring = smoothstep(0.07, 0.0, abs(r - table_r));
	float chase = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(a * 6.0 - TIME * 2.2), 6.0);
	vec3 emit = accent * ring * (0.9 * chase + 0.35 + pulse * 3.0);
	// halo suave em volta do anel
	emit += accent * smoothstep(0.9, 0.0, abs(r - table_r)) * 0.025 * (1.0 + pulse * 4.0);
	// longe: some na cor do fundo
	float fade = smoothstep(table_r + 1.0, 18.0, r);
	ALBEDO = mix(col, vec3(0.0), fade);
	EMISSION = emit * (1.0 - fade) + far_col * fade;
	ROUGHNESS = mix(0.18, 0.6, fade);
	METALLIC = 0.2;
	SPECULAR = 0.6;
	// semitransparente perto do carro: o reflexo (carro espelhado) aparece por baixo
	ALPHA = mix(1.0 - refl * (1.0 - smoothstep(0.0, table_r + 2.5, r)), 1.0, fade);
}
