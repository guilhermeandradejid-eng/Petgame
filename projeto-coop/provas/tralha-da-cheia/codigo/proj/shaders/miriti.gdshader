// Miriti facetado e fosco: atlas pintado por faceta (pintura.py) + toon de 3 degraus por light().
// Sem especular, sombra = multiplicar por uma tinta (nunca preto). Extras da Despedida: racha pelas facetas
// (alfa do atlas = distância até a aresta da faceta), dois tons e tremor; clarão de impacto.
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 shadow_tint : source_color = vec3(0.56, 0.50, 0.70);
uniform float mid = 0.74;          // valor do degrau do meio
uniform float flash = 0.0;         // clarão (0..1)
uniform float racha = 0.0;         // 0..1: rachaduras claras ao longo das facetas
uniform float dois_tons = 0.0;     // 1: vira 2 tons (creme na luz, tinta na sombra)
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.45);
uniform float rim_amt = 0.0;       // contraluz (só no nível PC)
uniform vec3 rim_col : source_color = vec3(1.0, 0.85, 0.62);
uniform float tremor = 0.0;        // deslocamento horizontal em degrau (metros)
uniform float tempo_q = 0.0;       // tempo em degrau, para o tremor
uniform float encharcado = 0.0;    // parte de baixo molhada (Boia, água rasa)
// v2: recorte de jogador (facetas de borda tingidas com a cor do dono) e contraluz quente do quadro bonito
uniform vec3 rim_jog : source_color = vec3(0.0);
uniform float rim_jog_amt = 0.0;
uniform vec3 contraluz_dir = vec3(0.3, 0.5, -0.8);   // de onde vem a contraluz (mundo)
uniform vec3 contraluz_cor : source_color = vec3(1.0, 0.78, 0.5);
uniform float contraluz = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	if (tremor > 0.0) {
		VERTEX.x += tremor * sin(tempo_q * 7.0 + VERTEX.y * 3.0);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec4 t = texture(atlas, UV);
	vec3 c = t.rgb;
	if (encharcado > 0.0) {
		c *= mix(vec3(1.0), vec3(0.62, 0.7, 0.78), smoothstep(encharcado + 0.03, encharcado - 0.03, wpos.y));
	}
	float crack = 0.0;
	if (racha > 0.0) {
		crack = 1.0 - smoothstep(0.03 * racha, 0.07 * racha, t.a);
	}
	if (dois_tons > 0.5) {
		float l = step(0.05, dot(normalize(wnrm), normalize(sun_dir)));
		vec3 two = mix(vec3(0.118, 0.102, 0.133), vec3(0.93, 0.88, 0.78), l);
		ALBEDO = vec3(0.0);
		EMISSION = mix(two, vec3(1.0, 0.97, 0.9), crack);
	} else {
		ALBEDO = mix(c, vec3(1.0, 0.96, 0.86), crack);
		EMISSION = vec3(1.0, 0.9, 0.7) * crack * 0.8 + vec3(0.9, 0.86, 0.8) * flash;
		if (rim_jog_amt > 0.0 || contraluz > 0.0) {
			vec3 nw = normalize(wnrm);
			vec3 vw = normalize(CAMERA_POSITION_WORLD - wpos);
			float fr = 1.0 - clamp(dot(nw, vw), 0.0, 1.0);
			// em degrau, como o resto do toon: só as facetas quase de perfil para a câmera
			float borda = smoothstep(0.6, 0.66, fr);
			EMISSION += rim_jog * borda * rim_jog_amt;
			float atras = smoothstep(0.05, 0.25, dot(nw, normalize(contraluz_dir)));
			EMISSION += contraluz_cor * smoothstep(0.42, 0.5, fr) * atras * contraluz;
		}
	}
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k1 = smoothstep(-0.03, 0.03, ndl) * ATTENUATION;
	float k2 = smoothstep(0.42, 0.48, ndl) * ATTENUATION;
	vec3 lv = mix(shadow_tint, vec3(mid), k1);
	lv = mix(lv, vec3(1.0), k2);
	lv *= 0.96 + 0.08 * clamp(ndl, 0.0, 1.0);
	DIFFUSE_LIGHT += lv * LIGHT_COLOR / PI;
	if (rim_amt > 0.0) {
		float rim = smoothstep(0.55, 0.6, 1.0 - dot(NORMAL, VIEW)) * smoothstep(-0.2, 0.3, -dot(LIGHT, VIEW));
		DIFFUSE_LIGHT += rim * rim_amt * rim_col * LIGHT_COLOR / PI * ATTENUATION;
	}
}
