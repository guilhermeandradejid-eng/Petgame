// Shell fur: the mesh is drawn several times, each shell pushed out along the normal.
// Vertex colour carries the fur colour (rgb) and length (a), baked in Blender from the same
// marking regions as the rendered model. Strands come from a per-texel random texture.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float shell = 0.0;            // 0 = skin, 1 = tips
uniform float fur_length = 0.045;
uniform float density = 5.0;          // strand texture repeats per UV unit
uniform sampler2D strands : filter_nearest_mipmap, repeat_enable;
uniform vec3 droop = vec3(0.0, -0.35, 0.15);

varying float flen;

void vertex() {
	flen = COLOR.a;
	float h = shell;
	VERTEX += NORMAL * fur_length * flen * h;
	VERTEX += droop * fur_length * flen * h * h;
}

void fragment() {
	float n = texture(strands, UV * density).r;
	if (shell > 0.0) {
		// strands taper: fewer survive the higher the shell
		if (flen < 0.03 || n < 0.08 + shell * 0.88) {
			discard;
		}
	}
	vec3 c = COLOR.rgb;
	float ao = mix(0.72, 1.18, shell);   // a little shadow near the skin, light tips
	ALBEDO = c * ao;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * rim * 0.18 * shell;
}
