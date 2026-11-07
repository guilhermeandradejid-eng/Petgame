shader_type canvas_item;
// Pós-processamento de tela: blur radial, aberração cromática, linhas de velocidade, vinheta, flash e saturação.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float aberr = 0.0;
uniform float lines = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float vig = 0.3;
uniform float sat = 1.1;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.777;

float hash(float p) { return fract(sin(p * 91.7) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	vec2 da = vec2(d.x * aspect, d.y);
	float r = length(da);
	float amt = blur * smoothstep(0.1, 0.8, r);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float k = float(i) / 7.0;
		vec2 u = uv - d * amt * k * 0.05;
		vec2 ab = d * aberr * 0.008;
		col.r += texture(screen_tex, u + ab).r;
		col.g += texture(screen_tex, u).g;
		col.b += texture(screen_tex, u - ab).b;
	}
	col /= 8.0;
	// linhas de velocidade (estilo anime), saindo do carro
	float ang = atan(da.y, da.x);
	float cell = floor(ang * 38.0);
	float h = hash(cell);
	float thin = smoothstep(0.5, 0.0, abs(fract(ang * 38.0) - 0.5) * 2.0 - 0.0);
	float flick = step(0.55, hash(cell + floor(TIME * 18.0)));
	float ln = step(0.6, h) * flick * smoothstep(0.35 + h * 0.2, 0.95, r) * thin;
	col += vec3(1.0) * ln * lines * 0.55;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col *= 1.0 - vig * smoothstep(0.45, 1.1, r);
	col = mix(col, flash.rgb, flash.a);
	COLOR = vec4(col, 1.0);
}
