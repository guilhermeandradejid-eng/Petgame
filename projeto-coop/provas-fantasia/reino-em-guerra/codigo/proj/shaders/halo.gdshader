// Halo dos olhos dos mortos: cartão virado para a câmera com grão de aquatinta verde-mordente que rareia para fora
// (o "bloom" da gravura: pontos, não degradê). Some com 'aceso'.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform vec3 cor : source_color = vec3(0.659, 0.847, 0.165);
uniform float aceso = 1.0;
uniform float forca = 0.5;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = dot(o.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	o.y -= curva_k * e * e;
	vec3 r = INV_VIEW_MATRIX[0].xyz; vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 vd = normalize(INV_VIEW_MATRIX[3].xyz - o);
	vec3 w = o + vd * 0.12 + (r * VERTEX.x + u * VERTEX.y);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	if (aceso <= 0.05) discard;
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c * vec2(0.8, 1.15)) * 1.25;
	float a = smoothstep(1.0, 0.15, r) * forca * aceso;
	float g = texture(grao, FRAGCOORD.xy / 256.0).r;
	if (g > a) discard;
	ALBEDO = cor;
}
