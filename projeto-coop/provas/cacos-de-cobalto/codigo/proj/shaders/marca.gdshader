// Marcas no chão (quad deitado): anel e símbolo do jogador, telegrafia vermelho-lacre que se fecha
// (círculo com dentes para dentro e retângulo com hachura), sombra de contato multiplicada por cobalto.
// Bordas com ruído de pincel; sem degradê liso.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform int kind = 0;            // 0 anel+símbolo, 1 telegrafia círculo, 2 telegrafia retângulo, 3 sombra, 5 sombra de inimigo (borda em cacos)
uniform int symbol = 0;          // 0 quadrado, 1 triângulo, 2 círculo, 3 losango
uniform vec3 col : source_color = vec3(0.894, 0.235, 0.620);
uniform vec3 edge : source_color = vec3(0.051, 0.063, 0.161);
uniform float progress = 0.5;    // telegrafia: 0 começa, 1 golpe
uniform float aspect = 1.0;      // largura/profundidade do quad (retângulo)
uniform float alpha = 1.0;
uniform float time = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.54, 0.80);
uniform float qsize = 1.0;        // lado do quad em metros (larguras de linha em metros)
uniform float line_m = 0.022;    // meia largura da linha da telegrafia (~8 px a 1080 na câmera de combate)
uniform float fill_a = 0.25;     // alfa do preenchimento que cresce com o wind-up
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float sdbox(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float sdtri(vec2 p, float r) {
	const float k = sqrt(3.0);
	p.x = abs(p.x) - r; p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = (vn(UV * 40.0) - 0.5) * 0.03;
	vec4 o = vec4(0.0);
	if (kind == 0) {
		float r = length(p);
		float ring = 1.0 - smoothstep(0.035, 0.05, abs(r - 0.86) + n);
		float rim = 1.0 - smoothstep(0.085, 0.1, abs(r - 0.86) + n);
		// símbolo na frente do anel (lado da câmera), para não sumir sob o corpo
		vec2 q = (p - vec2(0.0, 0.86)) / 0.26;
		float d;
		if (symbol == 0) d = sdbox(q, vec2(0.62));
		else if (symbol == 1) d = sdtri(vec2(q.x, -q.y), 0.72);
		else if (symbol == 2) d = length(q) - 0.7;
		else d = sdbox(mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * q, vec2(0.52));
		float sym = 1.0 - smoothstep(-0.02, 0.04, d + n * 3.0);
		float sye = 1.0 - smoothstep(0.14, 0.2, d + n * 3.0);
		float c = max(ring, sym);
		float e = max(rim, sye);
		o = vec4(mix(edge, col, c), e * alpha);
	} else if (kind == 1) {
		// telegrafia circular: anel fino + preenchimento radial que cresce do centro com o wind-up
		float r = length(p);
		float lw = line_m / (qsize * 0.5);
		float outer = 1.0 - smoothstep(lw * 0.7, lw * 1.2, abs(r - 0.96) + n * 0.4);
		float fillr = progress * 0.96;
		float fill = (1.0 - smoothstep(fillr - 0.008, fillr + 0.008, r + n * 0.5)) * fill_a;
		float front = (1.0 - smoothstep(lw * 0.4, lw * 0.9, abs(r - fillr) + n * 0.4)) * 0.55 * step(0.02, progress);
		o = vec4(col, max(outer, max(fill, front)) * alpha);
	} else if (kind == 2) {
		// telegrafia retangular: borda fina; o preenchimento avança da base (inimigo) para a ponta
		vec2 q = p * vec2(aspect, 1.0);
		float d = sdbox(q, vec2(aspect, 1.0) * 0.96);
		float lw = line_m / (qsize * 0.5);
		float border = 1.0 - smoothstep(lw * 0.7, lw * 1.2, abs(d) + n * 0.4);
		float yf = mix(1.0, -0.96, progress);
		float fill = step(yf, p.y) * step(d, 0.0) * fill_a;
		float front = (1.0 - smoothstep(lw * 0.4, lw * 0.9, abs(p.y - yf))) * step(d, 0.0) * 0.55 * step(0.02, progress);
		o = vec4(col, max(border, max(fill, front)) * alpha);
	} else if (kind == 3) {
		float r = length(p * vec2(1.0, 1.0));
		float m = 1.0 - smoothstep(0.78, 0.86, r + n * 2.0);
		o = vec4(shadow_tint, m * alpha);
	} else if (kind == 5) {
		// sombra de inimigo: mancha de contato mais escura com borda quebrada em cacos (ameaça sutil)
		float a = atan(p.y, p.x);
		float k = floor((a / 6.2831 + 0.5) * 11.0);
		float jag = 0.06 * (hash(vec2(k, 3.0)) - 0.5) + 0.05 * abs(fract((a / 6.2831 + 0.5) * 11.0) - 0.5);
		float r = length(p);
		float m = 1.0 - smoothstep(0.70, 0.74, r + jag + n);
		o = vec4(shadow_tint * 0.62, m * alpha);
	} else if (kind == 6) {
		// base em brasa do Incêndio: chão chamuscado com veios de brasa que respiram (máscara de ruído animada)
		float r = length(p);
		float m = 1.0 - smoothstep(0.86, 0.88, r + (vn(UV * 6.0) - 0.5) * 0.25 + (vn(UV * 30.0) - 0.5) * 0.05);
		float tq = floor(time * 12.0);
		float v = vn(UV * 9.0 + vec2(0.0, tq * 0.07)) * 0.6 + vn(UV * 23.0 - vec2(tq * 0.05, 0.0)) * 0.4;
		float vein = smoothstep(0.58, 0.62, v) * (1.0 - smoothstep(0.55, 0.85, r));
		vec3 c = mix(vec3(0.16, 0.10, 0.09), vec3(0.855, 0.416, 0.173), vein);
		c = mix(c, vec3(0.886, 0.678, 0.239), step(0.7, v) * vein);
		o = vec4(c, m * alpha);
	}
	if (o.a < 0.01) discard;
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
