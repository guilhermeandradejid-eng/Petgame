shader_type spatial;
render_mode specular_disabled;
uniform vec3 c : source_color = vec3(0.745, 0.462, 0.068);
void fragment() { ALBEDO = c; }
void light() { DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI; }
