// Chama de Incêndio no estilo de pintura de azulejo (billboard vertical): língua em S com ponta
// enrolada, contorno de cobalto a pincel, duas cores (laranja-ferro e amarelo-ocre) em pinceladas
// visíveis no sentido da chama. Flipbook de 4 quadros a 12 por segundo; cada instância tem fase
// própria (seed), então o fogo não pulsa em uníssono.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform vec3 col : source_color = vec3(0.855, 0.416, 0.173);   // laranja-ferro
uniform vec3 core : source_color = vec3(0.886, 0.678, 0.239);  // amarelo-ocre
uniform vec3 edge : source_color = vec3(0.114, 0.153, 0.333);  // cobalto (azul-noite)
uniform float time = 0.0;
uniform float seed = 0.0;
uniform float emit = 1.25;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 wp = MODEL_MATRIX[3].xyz + cam_right * VERTEX.x * length(MODEL_MATRIX[0].xyz) + vec3(0.0, 1.0, 0.0) * VERTEX.y * length(MODEL_MATRIX[1].xyz);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}
// língua de fogo como gota que sobe e enrola: barriga redonda embaixo, ponta fina em S
vec2 tongue(vec2 uv, float k, float s, float lean) {
	float y = uv.y;
	float ph = hash(vec2(k, s)) * 6.28;
	float amp = 0.07 + 0.05 * hash(vec2(k + 2.0, s));
	float cx = 0.5 + lean * y + amp * sin(y * 5.0 + ph) * y * y * 2.2;
	float belly = smoothstep(0.0, 0.22, y) * (1.0 - 0.15 * y);
	float w = 0.34 * pow(max(1.0 - y, 0.0), 1.35) * (0.55 + 0.45 * belly) * sqrt(clamp(y / 0.12, 0.0, 1.0)) * (0.9 + 0.2 * hash(vec2(k, s + 5.0)));
	return vec2(w - abs(uv.x - cx), cx);
}
void fragment() {
	float k = mod(floor(time * 12.0 + seed * 4.0), 4.0);   // flipbook de 4 quadros a 12 fps
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 t1 = tongue(uv, k, seed, 0.0);
	vec2 t2 = tongue(vec2((uv.x - 0.2) * 1.5 + 0.5, uv.y * 1.45), k + 7.0, seed + 1.0, 0.12);
	vec2 t3 = tongue(vec2((uv.x + 0.18) * 1.7 + 0.5, uv.y * 1.8), k + 13.0, seed + 2.0, -0.15);
	float d = max(t1.x, max(t2.x * 0.7, t3.x * 0.6));
	float wob = (vn(vec2(uv.y * 30.0, k * 3.0 + seed)) - 0.5) * 0.018;   // borda de pincel
	d += wob;
	float lw = 0.035;
	if (d < -lw) discard;
	// miolo ocre: uma segunda gota menor, deslocada para baixo (pincelada de dentro)
	vec2 ti = tongue(vec2((uv.x - t1.y) * 1.7 + 0.5, (uv.y + 0.06) * 1.55), k + 3.0, seed + 4.0, 0.0);
	float inner = step(0.0, ti.x + (vn(vec2(uv.y * 18.0, k + seed)) - 0.5) * 0.03);
	vec3 c = mix(col, core, inner);
	// pinceladas visíveis: estrias finas no sentido da chama, alternando as duas cores
	float along = (uv.x - t1.y) * 16.0 + vn(vec2(uv.y * 4.0, k + seed)) * 2.0;
	float strk = step(0.8, fract(along)) * step(0.05, d) * step(0.15, uv.y);
	c = mix(c, inner > 0.5 ? col : core, strk * 0.8);
	c = d < 0.0 ? edge : c;
	ALBEDO = c;
	EMISSION = d < 0.0 ? vec3(0.0) : c * emit;
}
