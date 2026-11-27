// Chuva em traços diagonais de buril (afinam nas pontas) e cinzas do moinho, numa caixa que acompanha o foco.
// Posição 100% determinística a partir do tempo global (o Movie Maker repete igual), mesma coisa no Compatibility.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled;
global uniform vec3 foco;
global uniform float tempo;
global uniform vec2 vento;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform int modo = 0;            // 0 chuva, 1 cinza, 2 palha, 3 brasa (sobe do fogo)
uniform vec3 brasa : source_color = vec3(0.886, 0.404, 0.169);
uniform vec3 origem = vec3(0.0);
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform vec3 papel : source_color = vec3(0.557, 0.592, 0.639);
uniform vec3 papel2 : source_color = vec3(0.914, 0.875, 0.788);
uniform float intens = 1.0;
uniform vec3 caixa = vec3(30.0, 10.0, 30.0);
varying vec2 v_uv;
varying float v_k;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	v_uv = UV;
	v_k = c.w;
	if (c.w > intens) { POSITION = vec4(2.0, 2.0, 2.0, 1.0); }
	else {
		vec3 dir; float len; float wid; vec3 p;
		if (modo == 0) {
			float spd = 11.0 + c.z * 4.0;
			float ph = fract(c.z * 7.31 + tempo * spd / caixa.y);
			dir = normalize(vec3(vento.x * 0.38, -1.0, vento.y * 0.38));
			p = foco + vec3((c.x - 0.5) * caixa.x, caixa.y * (1.0 - ph) - 1.0, (c.y - 0.5) * caixa.z - 3.0);
			p.xz -= dir.xz * caixa.y * (1.0 - ph);
			len = 0.3 + 0.2 * c.w;
			wid = 0.006;
		} else if (modo == 3) {
			float ph = fract(c.z * 5.3 + tempo * (0.35 + 0.3 * c.w));
			p = origem + vec3((c.x - 0.5) * caixa.x, ph * caixa.y, (c.y - 0.5) * caixa.z) + vec3(vento.x, 0.0, vento.y) * ph * ph * 3.0
				+ vec3(sin(tempo * 4.0 + c.x * 30.0), 0.0, cos(tempo * 3.0 + c.y * 20.0)) * 0.15 * ph;
			dir = normalize(vec3(vento.x * 0.5, 1.0, vento.y * 0.5));
			len = 0.05 * (1.0 - ph) + 0.01;
			wid = 0.035 * (1.0 - ph * 0.7);
		} else {
			float spd = 0.6 + c.z * 0.5;
			float ph = fract(c.z * 3.1 + tempo * spd / caixa.y);
			vec3 sw = vec3(sin(tempo * 1.7 + c.x * 20.0), 0.0, cos(tempo * 1.3 + c.y * 17.0)) * 0.6;
			p = foco + vec3((c.x - 0.5) * caixa.x, caixa.y * (1.0 - ph) - 1.0, (c.y - 0.5) * caixa.z - 6.0) + sw + vec3(vento.x, 0.0, vento.y) * ph * 6.0;
			dir = normalize(vec3(sin(tempo * 3.0 + c.x * 40.0), 0.6, cos(tempo * 2.0 + c.y * 30.0)));
			len = modo == 1 ? 0.035 : 0.16;
			wid = modo == 1 ? 0.03 : 0.025;
		}
		if (modo == 0 && length(CAMERA_POSITION_WORLD - p) < 7.0) { p += vec3(0.0, -60.0, 0.0); }   // nada de traço gigante colado na lente
		vec3 vd = normalize(CAMERA_POSITION_WORLD - p);
		vec3 side = normalize(cross(dir, vd));
		vec3 w = p + side * (UV.x - 0.5) * wid + dir * (1.0 - UV.y) * len;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	}
}
void fragment() {
	float x = abs(v_uv.x - 0.5) * 2.0;
	float taper = sin(3.14159 * v_uv.y);
	if (modo == 0) {
		if (x > taper * 0.9) discard;
		ALBEDO = mix(tinta, papel, step(0.6, v_k));
	} else if (modo == 1) {
		vec2 c = v_uv * 2.0 - 1.0;
		if (length(c) > 0.9) discard;
		ALBEDO = mix(papel2, tinta, step(0.75, v_k));
	} else if (modo == 3) {
		vec2 c = v_uv * 2.0 - 1.0;
		if (length(c) > 0.9) discard;
		ALBEDO = mix(brasa, papel2, step(0.7, v_k)) * 1.3;
	} else {
		if (x > taper) discard;
		ALBEDO = vec3(0.788, 0.647, 0.353);
	}
}
