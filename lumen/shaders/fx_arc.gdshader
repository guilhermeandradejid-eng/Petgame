// Fitas de efeito (cortes de espada, rastros, raios, feixes): UV.x ao longo, UV.y atraves.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 color : source_color = vec4(1.0);
uniform float progress = 0.0;   // 0..1 vida do efeito
uniform float sweep = 1.0;      // 1 = a fita e "desenhada" de u=0 ate u=1; 0 = aparece inteira
uniform float scroll = 2.0;
uniform float fade = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float band = smoothstep(0.0, 0.45, v) * smoothstep(1.0, 0.82, v);
	float head = progress * 1.7;
	float reveal = mix(1.0, smoothstep(u - 0.02, u + 0.18, head), sweep);
	float tail = mix(1.0 - smoothstep(0.55, 1.0, progress), smoothstep(head - 1.1, head - 0.45, u), sweep);
	float taper = smoothstep(0.0, 0.2, u) * smoothstep(1.0, 0.75, u);
	float n = noise(vec2(u * 7.0 - TIME * scroll, v * 3.0));
	float a = band * reveal * tail * mix(1.0, taper, sweep) * (0.55 + 0.45 * n);
	float core = pow(band, 3.0) * smoothstep(0.55, 0.95, v);
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.7);
	ALPHA = clamp(a, 0.0, 1.0) * color.a * fade;
}
