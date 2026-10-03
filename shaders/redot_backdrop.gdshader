shader_type canvas_item;
render_mode unshaded;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud(vec2 p, vec2 center, vec2 spread) {
	vec2 d = (p - center) / spread;
	return exp(-dot(d, d));
}

void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	vec3 ink = vec3(0.0353, 0.0353, 0.0431);
	vec3 brand = vec3(1.0, 0.2314, 0.0392);
	float left_glow = cloud(p, vec2(10.0, 270.0), vec2(360.0, 330.0));
	float right_glow = cloud(p, vec2(1590.0, 700.0), vec2(370.0, 330.0));
	vec3 base = ink + brand * (left_glow * 0.075 + right_glow * 0.032);

	// Sparse square halftone clouds mirror the website's pixel-blast hero.
	vec2 cell = floor(p / 12.0);
	vec2 in_cell = abs(fract(p / 12.0) - 0.5);
	float noise = hash(cell);
	float dot_shape = (1.0 - smoothstep(0.11, 0.14, in_cell.x)) * (1.0 - smoothstep(0.11, 0.14, in_cell.y));
	float formation = cloud(p, vec2(290.0, 235.0), vec2(245.0, 240.0));
	formation += cloud(p, vec2(1175.0, 380.0), vec2(310.0, 285.0)) * 0.8;
	formation += cloud(p, vec2(1450.0, 790.0), vec2(220.0, 140.0)) * 0.65;
	float contour = 0.52 + sin(cell.x * 0.24 + cos(cell.y * 0.27)) * 0.27;
	float pixels = dot_shape * step(0.23, noise) * formation * contour;
	base += brand * pixels * 0.16;

	// Quiet graphite speckling and the warm section-divider glow.
	float grain = dot_shape * step(0.86, noise) * 0.006;
	base += vec3(grain);
	float divider = cloud(p, vec2(800.0, 852.0), vec2(470.0, 8.0));
	base += brand * divider * 0.055;
	COLOR = vec4(base, 1.0);
}
