// Emissive collectible / crystal material: pulsing core, fresnel halo and a
// sweeping glint, all unshaded so it reads in any lighting.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform float energy = 1.6;
uniform float pulse = 0.35;
uniform float glint = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float p = 1.0 + pulse * sin(TIME * 4.0 + wpos.x * 1.3 + wpos.z);
	float g = smoothstep(0.92, 1.0, sin(wpos.y * 3.0 + wpos.x * 2.0 - TIME * 3.0)) * glint;
	vec3 c = color.rgb * (0.7 + 0.3 * (1.0 - fres)) + rim.rgb * fres * 0.9 + vec3(g);
	ALBEDO = c;
	EMISSION = c * energy * p * 0.6;
}
