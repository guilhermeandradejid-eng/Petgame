// Safe-mode stand-in for sky.gdshader.
shader_type sky;
uniform vec4 zenith : source_color = vec4(0.32, 0.55, 0.95, 1.0);
uniform vec4 horizon : source_color = vec4(0.98, 0.82, 0.72, 1.0);
void sky() {
	COLOR = mix(horizon.rgb, zenith.rgb, clamp(EYEDIR.y * 2.0, 0.0, 1.0));
}
