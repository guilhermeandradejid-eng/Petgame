// Safe-mode stand-in for toon.gdshader (same uniform names, standard lighting).
shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float hit_flash = 0.0;
void fragment() {
	ALBEDO = mix(albedo.rgb, vec3(1.0), hit_flash);
	EMISSION = emission.rgb * emission_energy;
	ROUGHNESS = 0.8;
}
