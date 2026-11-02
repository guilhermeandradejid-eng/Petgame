// Torcida em MultiMesh: cada boneco pula num ritmo próprio
shader_type spatial;
render_mode unshaded;

uniform float excitement = 0.0;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float speed = 4.0 + seed * 5.0;
	float hop = abs(sin(TIME * speed + seed * 31.0));
	VERTEX.y += hop * (0.05 + excitement * 0.45);
	VERTEX.x += sin(TIME * 2.0 + seed * 12.0) * 0.04 * VERTEX.y;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float l = clamp(NORMAL.y * 0.5 + NORMAL.z * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = base * (l > 0.45 ? 1.0 : 0.78);
}
