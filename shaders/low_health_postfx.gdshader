shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float max_desaturation : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.08;

uniform float pulse_speed : hint_range(0.0, 6.0) = 1.2;
uniform float pulse_amount : hint_range(0.0, 0.35) = 0.06;

void fragment() {
	vec4 src = texture(SCREEN_TEXTURE, SCREEN_UV);
	float s = clamp(strength, 0.0, 1.0);

	// Luma-weighted grayscale mix for subtle desaturation.
	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	float desat = s * max_desaturation;
	vec3 graded = mix(src.rgb, vec3(luma), desat);

	// Gentle heartbeat pulse.
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount * s;

	// Very subtle vignette darkening near edges.
	vec2 d = SCREEN_UV - vec2(0.5);
	float r = length(d) * 1.41421356; // approx normalize radius to ~[0..1]
	float vignette = smoothstep(0.35, 1.0, r);
	float darken = vignette_strength * s * pulse * vignette;

	graded *= (1.0 - darken);
	COLOR = vec4(graded, src.a);
}
