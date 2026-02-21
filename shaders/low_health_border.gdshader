shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.08, 0.08, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float min_thickness : hint_range(0.0, 0.2) = 0.02;
uniform float max_thickness : hint_range(0.0, 0.5) = 0.22;
uniform float edge_softness : hint_range(0.001, 0.08) = 0.02;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.28;
uniform float noise_scale : hint_range(2.0, 40.0) = 14.0;
uniform float edge_irregularity : hint_range(0.0, 0.12) = 0.035;
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.4;
uniform float pulse_amount : hint_range(0.0, 0.35) = 0.08;
uniform float roundness : hint_range(0.0, 1.0) = 0.45;
uniform float angular_warp_strength : hint_range(0.0, 0.18) = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);

	float s = clamp(strength, 0.0, 1.0);
	float thickness = mix(min_thickness, max_thickness, s);

	// Base edge distances
	float edge_rect = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float edge_circle = 0.5 - length(centered);
	float dist_to_edge = mix(edge_rect, edge_circle, roundness);

	// Organic randomness:
	// 1) local UV noise, 2) angular noise so edges are not straight/parallel.
	float n_local = fbm(uv * noise_scale + vec2(TIME * 0.03, -TIME * 0.02));
	float angle = atan(centered.y, centered.x);
	float n_angular = fbm(vec2(angle * 2.5, TIME * 0.02 + 17.0));

	float jitter_local = (n_local - 0.5) * 2.0 * edge_irregularity * s;
	float jitter_angular = (n_angular - 0.5) * 2.0 * angular_warp_strength * s;
	float local_thickness = max(0.001, thickness + jitter_local + jitter_angular);

	float border = 1.0 - smoothstep(local_thickness - edge_softness, local_thickness + edge_softness, dist_to_edge);

	// Slight "breathing" pulse to communicate danger without obscuring view.
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount * s;
	float alpha_scale = mix(min_alpha, max_alpha, s) * pulse;

	COLOR = vec4(border_color.rgb, border_color.a * border * alpha_scale);
}
