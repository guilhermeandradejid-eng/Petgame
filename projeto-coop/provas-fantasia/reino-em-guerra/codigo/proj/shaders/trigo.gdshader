// Trigo da margem retomada (MultiMesh): cada pé é um traço de buril vertical; a espiga é aguada ocre-amarela e o pé
// afunda em tinta. O vento passa em faixas (ondas que andam na direção do vento), com degrau de 2 quadros.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float tempo;
global uniform vec2 vento;
global uniform sampler2D grao : filter_nearest, repeat_enable;
global uniform vec4 nevoa;
global uniform vec4 papel_frio : source_color;
global uniform vec4 papel_quente : source_color;
global uniform int n_luzes;
global uniform sampler2D luzes : filter_nearest;
uniform vec3 cor_espiga : source_color = vec3(0.788, 0.647, 0.353);
uniform vec3 cor_sombra : source_color = vec3(0.431, 0.290, 0.200);
uniform vec3 cor_tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform float forca = 1.0;
varying float v_h;
varying vec3 v_w;
varying float v_ca;
void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(UV.y, 0.0, 1.0);
	v_h = h;
	float tq = floor(tempo * 30.0) / 30.0;
	float onda = sin(dot(base.xz, normalize(vento)) * 0.55 - tq * 2.6) * 0.5 + 0.5;
	float raj = sin(dot(base.xz, vec2(0.21, 0.37)) * 1.3 - tq * 4.1 + INSTANCE_CUSTOM.x * 6.28) * 0.15;
	vec2 off = normalize(vento) * (onda * 0.22 + raj + 0.06) * h * h * forca;
	VERTEX.xz += off;
	VERTEX.y -= length(off) * 0.35 * h;
	float d = dot(VERTEX.xz - foco.xz, curva_dir);   // tronco que rola: o chão cai para o norte, o horizonte fica reto
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
	v_w = VERTEX;
	v_ca = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec4 G = texture(grao, FRAGCOORD.xy / 256.0);
	float g = G.r * 0.996 + 0.002;
	// pé em tinta até 45%, espiga colorida em cima; algumas espigas descoradas (papel)
	// low key: o trigal é sombra-queimada; só perto das tochas, velas e lanternas a espiga acende em ocre
	float acesa = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= n_luzes) break;
		vec4 L = texelFetch(luzes, ivec2(i, 0), 0);
		vec4 Ex = texelFetch(luzes, ivec2(i, 1), 0);
		float k = clamp(1.0 - length(v_w - L.xyz) / max(L.w * 1.25, 0.01), 0.0, 1.0) * Ex.x;
		acesa = max(acesa, k);
	}
	vec3 esp = g < acesa * 1.6 ? cor_espiga : (v_ca > 0.55 ? cor_espiga : cor_sombra);
	vec3 c = mix(cor_tinta, esp, step(0.45 + 0.2 * v_ca, v_h));
	if (v_ca > 0.8) c = mix(cor_tinta, g < acesa * 1.6 ? papel_quente.rgb : cor_sombra, step(0.5, v_h));
	float dc = length(v_w - CAMERA_POSITION_WORLD);
	float nv = smoothstep(nevoa.x, nevoa.y, dc) * nevoa.z;
	vec3 pn = mix(papel_frio.rgb, papel_quente.rgb, nevoa.w);
	c = mix(c, pn, step(g, nv));
	ALBEDO = c;
}
