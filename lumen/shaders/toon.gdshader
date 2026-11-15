// Toon suave em duas faixas, com brilho de borda (rim) do lado iluminado.
// A cor da sombra vem da luz ambiente da cena (fria/arroxeada), nao daqui.
// Serve para herois, inimigos e cenario: vento, dissolver e flash sao opcionais.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float vcol_mix : hint_range(0.0, 1.0) = 1.0;
uniform float band : hint_range(0.005, 0.5) = 0.07;
uniform float wrap : hint_range(-0.5, 0.5) = 0.02;
uniform float half_tone : hint_range(0.0, 1.0) = 0.22;
uniform float rim : hint_range(0.0, 3.0) = 0.9;
uniform float rim_power : hint_range(0.5, 8.0) = 3.2;
uniform float gloss : hint_range(0.0, 2.0) = 0.0;
uniform float gloss_size : hint_range(0.0, 1.0) = 0.12;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float shade_boost : hint_range(0.0, 8.0) = 0.0;
uniform float wind : hint_range(0.0, 4.0) = 0.0;

instance uniform vec3 flash_color : source_color = vec3(1.0);
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind > 0.0) {
		float h = max(VERTEX.y, 0.0);
		float t = TIME * 1.5 + world_pos.x * 0.35 + world_pos.z * 0.27;
		VERTEX.x += sin(t) * 0.035 * wind * h;
		VERTEX.z += cos(t * 0.8 + 1.3) * 0.028 * wind * h;
	}
}

void fragment() {
	vec3 base = tint * mix(vec3(1.0), COLOR.rgb, vcol_mix);
	if (dissolve > 0.0) {
		vec3 cell = floor(world_pos * 16.0);
		float n = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		if (n < dissolve) {
			discard;
		}
	}
	ALBEDO = mix(base, flash_color, flash);
	EMISSION = emission * emission_energy + base * shade_boost + flash_color * flash * 1.2
		+ vec3(0.5, 0.95, 1.0) * dissolve * 0.8;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(wrap - band, wrap + band, ndl);
	float lit2 = smoothstep(0.62 - band, 0.62 + band, ndl);
	float k = lit * (1.0 - half_tone) + lit2 * half_tone;
	float att = ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * (k * att) / PI;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, rim_power);
	DIFFUSE_LIGHT += LIGHT_COLOR * (smoothstep(0.35, 0.6, fres) * lit * att * rim) / PI;
	if (gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float s = smoothstep(1.0 - gloss_size, 1.0 - gloss_size + 0.03, ndh);
		SPECULAR_LIGHT += LIGHT_COLOR * (s * att * gloss) / PI;
	}
}
