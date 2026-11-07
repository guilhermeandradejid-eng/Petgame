shader_type spatial;
render_mode unshaded, cull_disabled;
// Boost pad: setas que correm no sentido da pista
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float y = fract(uv.y * 2.0 + TIME * 2.2);
	float x = abs(uv.x - 0.5);
	float chev = smoothstep(0.08, 0.0, abs(y - 0.35 - x * 0.9) - 0.06);
	vec3 base = vec3(0.05, 0.75, 1.0);
	vec3 col = mix(base, vec3(0.9, 1.0, 1.0), chev);
	float border = step(0.44, x) + step(0.97, abs(uv.y - 0.5) * 2.0);
	col = mix(col, vec3(1.0), clamp(border, 0.0, 1.0));
	ALBEDO = col * 2.2;
}
