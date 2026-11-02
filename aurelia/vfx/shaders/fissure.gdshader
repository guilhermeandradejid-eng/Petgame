// Glowing ground crack that races forward (axe "Quake Cleave").
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 1.0;

float hash(float n) { return fract(sin(n * 91.3 + seed) * 43758.5453); }
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	float x = UV.x;
	float y = UV.y - 0.5;
	float wob = (noise(x * 22.0) - 0.5) * 0.28 + (noise(x * 61.0) - 0.5) * 0.07;
	float w = mix(0.11, 0.025, x);                    // wide at the axe, thin at the tip
	float d = abs(y - wob);
	float crack = smoothstep(w, w * 0.15, d);
	float glow = smoothstep(w * 4.0, 0.0, d) * 0.35;
	float reveal = smoothstep(progress, progress - 0.08, x);
	float head = smoothstep(0.1, 0.0, abs(x - progress)) * smoothstep(0.35, 0.0, abs(y - wob));
	float a = (crack + glow + head) * reveal * fade;
	ALBEDO = mix(color.rgb, vec3(1.0, 0.95, 0.7), crack * 0.5) * (0.8 + a);
	ALPHA = clamp(a, 0.0, 1.0);
}
