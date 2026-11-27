// Efeito chapado (lascas, fita, coroa, estalo): cor por instância, sem textura; 2 tons por normal fixa.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0);
uniform vec3 cor2 : source_color = vec3(0.118, 0.102, 0.133);
uniform float brilho = 0.0;
uniform float alfa = 1.0;
uniform bool dois_lados = false;   // verso em cor2 (fita que vira)
void fragment() {
	vec3 c = (dois_lados && !FRONT_FACING) ? cor2 : cor;
	ALBEDO = c * (1.0 + brilho);
	if (alfa < 0.999) {
		// transparência por pontilhado (sem ordenar), estável no Compatibility
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > alfa) discard;
	}
}
