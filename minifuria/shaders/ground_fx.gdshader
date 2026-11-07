shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Efeitos chapados no chão: sombra de contato (0), queimado (1), anel de choque (2), mancha de óleo (3).
uniform int mode = 0;
uniform float strength = 1.0;
uniform float ring_t = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 d = UV - 0.5;
	if (mode == 0) {
		// retângulo arredondado bem suave (ambient occlusion embaixo do carro)
		vec2 q = abs(d) * 2.0;
		float r = length(max(q - vec2(0.55, 0.7), 0.0)) + min(max(q.x - 0.55, q.y - 0.7), 0.0);
		float a = smoothstep(0.42, -0.1, r);
		ALBEDO = vec3(0.0);
		ALPHA = a * 0.62 * strength;
	} else if (mode == 1) {
		float r = length(d) * 2.0;
		float n = noise(UV * 9.0) * 0.5 + noise(UV * 23.0) * 0.5;
		float a = smoothstep(1.0, 0.2, r + n * 0.35);
		ALBEDO = vec3(0.02, 0.02, 0.025);
		ALPHA = a * 0.8 * strength;
	} else if (mode == 3) {
		float r = length(d) * 2.0;
		float n = noise(UV * 6.0) * 0.6 + noise(UV * 15.0) * 0.4;
		float a = smoothstep(1.0, 0.75, r + n * 0.3);
		float sheen = sin((r + n) * 18.0) * 0.5 + 0.5;
		vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (sheen + vec3(0.0, 0.33, 0.67)));
		ALBEDO = mix(vec3(0.02, 0.02, 0.03), rainbow * 0.5, 0.35 * smoothstep(0.3, 0.9, sheen));
		ALPHA = a * 0.92 * strength;
	} else {
		float r = length(d) * 2.0;
		float w = 0.08 + 0.1 * (1.0 - ring_t);
		float a = smoothstep(w, 0.0, abs(r - mix(0.15, 0.95, ring_t)));
		ALBEDO = tint.rgb * 3.0;
		ALPHA = a * (1.0 - ring_t) * strength;
	}
}
