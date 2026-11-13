shader_type canvas_item;
// Pós-processo de tela: onda de choque, aberração cromática, vinheta e dessaturação no K.O.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 shock_center = vec2(0.5);
uniform float shock_t = 1.0;
uniform float aberration = 0.0;
uniform float ko_desat = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 asp = vec2(16.0 / 9.0, 1.0);
	vec2 d = (uv - shock_center) * asp;
	float dist = length(d);
	float radius = shock_t * 0.9;
	float w = 0.06;
	float ring = (1.0 - smoothstep(0.0, w, abs(dist - radius))) * (1.0 - shock_t);
	uv -= normalize(d + 1e-5) / asp * ring * 0.025;
	vec2 dir = (uv - 0.5);
	float a = aberration * (0.4 + length(dir) * 1.6);
	vec3 col;
	col.r = texture(screen_tex, uv + dir * a).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * a).b;
	float vig = smoothstep(1.1, 0.35, length((SCREEN_UV - 0.5) * asp * 0.9));
	col *= mix(0.78, 1.0, vig);
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(1.05, 0.98, 1.1), ko_desat * 0.7);
	COLOR = vec4(col, 1.0);
}
