// Estilhaço vidrado: face em esmalte branco com um traço de cobalto, borda de biscoito cru
// (terracota nos inimigos). Luz toon fixa (2 degraus) e dissolve por limiar de ruído no fim.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 glaze : source_color = vec3(0.937, 0.914, 0.863);
uniform vec3 stroke : source_color = vec3(0.263, 0.388, 0.682);
uniform vec3 bisque : source_color = vec3(0.639, 0.345, 0.227);
uniform vec3 ink : source_color = vec3(0.051, 0.063, 0.161);
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.54, 0.80);
uniform vec3 sun = vec3(-0.45, 0.75, 0.45);
uniform vec3 half_size = vec3(0.03, 0.03, 0.006);
uniform float dissolve = 0.0;
uniform float hot = 0.0;               // brasa: estilhaço incandescente
uniform vec3 hot_col : source_color = vec3(0.855, 0.416, 0.173);
varying vec3 lp;
varying vec3 ln;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; ln = NORMAL; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 q = lp / half_size;
	float face = step(0.7, abs(ln.z));
	float border = step(0.78, max(abs(q.x), abs(q.y)));
	float h = hash(floor((lp.xy + 0.1) * 160.0));
	if (h < dissolve) discard;
	vec3 c = face > 0.5 ? (border > 0.5 ? ink : glaze) : bisque;
	if (face > 0.5 && ln.z > 0.0 && abs(q.x + q.y * 0.6) < 0.25) c = stroke;
	c = mix(c, hot_col, hot * (1.0 - border * face));
	float lit = step(0.0, dot(normalize(wn), normalize(sun)));
	ALBEDO = c * mix(shadow_tint, vec3(1.0), lit);
	EMISSION = hot_col * hot * 1.5;
}
