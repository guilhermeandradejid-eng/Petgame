shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.25, 0.68, 0.75, 0.82);
uniform vec4 foam : source_color = vec4(0.9, 1.0, 1.0, 1.0);

void fragment() {
	vec2 p = UV * vec2(24.0, 3.0);
	float w = sin(p.x * 3.0 + TIME * 1.6 + sin(p.y * 4.0 + TIME)) * 0.5 + 0.5;
	float streak = smoothstep(0.82, 0.95, sin(p.x * 1.7 - TIME * 1.1) * sin(p.y * 6.0 + TIME * 0.5));
	float edge = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.88, UV.y);
	ALBEDO = mix(shallow.rgb, foam.rgb, max(streak * 0.7, (1.0 - edge) * 0.8));
	ALPHA = shallow.a;
	ROUGHNESS = 0.25;
	METALLIC = 0.0;
	EMISSION = foam.rgb * w * 0.04;
}
