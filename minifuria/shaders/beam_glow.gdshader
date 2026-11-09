shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Brilho de feixe (portão laser, ímã): cilindro com borda suave (fresnel) e energia correndo ao longo dele.
uniform vec4 col : source_color = vec4(1.0, 0.15, 0.25, 1.0);
uniform float power = 1.0;
uniform float flow = 3.0;

float n1(float x) { return fract(sin(x * 12.9898) * 43758.5453); }
float vnoise(float x) { float i = floor(x); float f = fract(x); return mix(n1(i), n1(i + 1.0), f * f * (3.0 - 2.0 * f)); }

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.5);
	float along = UV.y;
	float wav = 0.65 + 0.35 * vnoise(along * 30.0 - TIME * flow * 6.0) + 0.25 * sin(along * 90.0 - TIME * flow * 20.0);
	ALBEDO = col.rgb * core * wav * power * 2.2;
	ALPHA = clamp(core * power, 0.0, 1.0);
}
