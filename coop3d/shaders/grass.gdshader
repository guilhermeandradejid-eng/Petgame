// Grass blades for MultiMeshInstance3D. Roots stay put (weight = UV.y),
// tips sway with layered wind and bend away from both players
// (positions come from global uniforms set every frame by the level).
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec4 root_color : source_color = vec4(0.25, 0.55, 0.26, 1.0);
uniform vec4 tip_color : source_color = vec4(0.72, 0.93, 0.45, 1.0);
uniform float sway = 0.18;
uniform float push_radius = 1.1;
global uniform vec3 player_pos_a;
global uniform vec3 player_pos_b;

varying float tipw;

vec3 push(vec3 w, vec3 p) {
	vec3 d = w - p;
	d.y = 0.0;
	float l = length(d);
	float k = (1.0 - smoothstep(0.0, push_radius, l)) * step(abs(w.y - p.y), 1.6);
	return normalize(d + vec3(0.001)) * k * 0.6;
}

void vertex() {
	float w = 1.0 - UV.y;  // 0 at root, 1 at tip
	tipw = w;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = origin.x * 0.35 + origin.z * 0.27;
	float gust = sin(TIME * 0.7 + origin.x * 0.05) * 0.5 + 0.5;
	vec3 wind = vec3(sin(TIME * 1.8 + ph), 0.0, cos(TIME * 1.3 + ph * 1.3) * 0.5) * sway * (0.6 + gust);
	vec3 off = (wind + push(world, player_pos_a) + push(world, player_pos_b)) * w * w;
	// convert the world offset into model space
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	VERTEX.y -= length(off) * 0.3 * w;
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, tipw);
	BACKLIGHT = vec3(0.3, 0.4, 0.1);
}
