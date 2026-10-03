shader_type canvas_item;
render_mode unshaded;

uniform float text_width = 325.0;
uniform float line_offset = 0.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float drift = sin(TIME * 0.34) * 0.075;
	float t = clamp(local_position.x / text_width * 0.76 + line_offset + drift, 0.0, 1.0);
	vec3 peach = vec3(1.0, 0.757, 0.678);
	vec3 coral = vec3(1.0, 0.475, 0.341);
	vec3 brand = vec3(1.0, 0.231, 0.039);
	vec3 amber = vec3(1.0, 0.478, 0.0);
	vec3 highlight = vec3(1.0, 0.816, 0.761);
	vec3 tint;
	if (t < 0.2) {
		tint = mix(peach, coral, smoothstep(0.0, 0.2, t));
	} else if (t < 0.43) {
		tint = mix(coral, brand, smoothstep(0.2, 0.43, t));
	} else if (t < 0.64) {
		tint = mix(brand, amber, smoothstep(0.43, 0.64, t));
	} else if (t < 0.78) {
		tint = mix(amber, brand, smoothstep(0.64, 0.78, t));
	} else {
		tint = mix(brand, highlight, smoothstep(0.78, 1.0, t));
	}
	// COLOR already includes the font atlas alpha and its antialiased edges.
	COLOR.rgb *= tint;
}
