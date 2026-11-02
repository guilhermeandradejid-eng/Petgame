// Crescent slash smear, camera-facing. Sweeps open along the arc (progress) then fades. Thin and
// translucent: it is a shape (crescent), not a blob.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float a0 = 2.2;          // start angle (radians, 0 = right, CCW positive)
uniform float a1 = -0.4;         // end angle
uniform float radius = 0.78;
uniform float thickness = 0.26;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float flip = 1.0;
uniform bool billboard = true;

void vertex() {
	if (billboard) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	if (billboard) MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.x *= flip;
	p.y = -p.y;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float span = a1 - a0;
	// angle parameter along the arc, wrapped into the same turn as a0
	float t = (ang - a0) / span;
	t = t - floor(t + 0.0);
	if (span < 0.0) {
		t = (a0 - ang) / -span;
		t = t - floor(t);
	}
	float inside = step(0.0, t) * step(t, 1.0);
	float head = progress;
	float shown = smoothstep(head, head - 0.35, t);           // tail trails behind the head
	float bell = pow(sin(clamp(t, 0.0, 1.0) * 3.14159), 0.7);
	float r_out = radius;
	float r_in = radius - thickness * bell;
	float band = smoothstep(r_in - 0.015, r_in + 0.02, r) * smoothstep(r_out + 0.015, r_out - 0.03, r);
	float a = band * shown * inside * fade;
	ALBEDO = color.rgb * (0.9 + a * 0.6);
	ALPHA = a * color.a * 0.72;
}
