shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.008;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float vertical_influence : hint_range(0.0, 1.0) = 0.7;
uniform vec2 scroll_speed = vec2(0.02, 0.1);

void fragment() {
	// Get screen texture coordinates
	vec2 uv = SCREEN_UV;
	
	// Create time-based animation
	float time_offset = TIME * wave_speed;
	
	// Calculate vertical gradient (stronger distortion at bottom, weaker at top)
	float vertical_gradient = pow(1.0 - UV.y, 2.0) * vertical_influence;
	
	// Generate wave patterns using sine waves at different frequencies
	float wave1 = sin((UV.y * wave_frequency) + time_offset + (UV.x * 2.0)) * 0.5;
	float wave2 = sin((UV.y * wave_frequency * 1.3) - time_offset * 0.7 + (UV.x * 3.0)) * 0.3;
	float wave3 = cos((UV.x * wave_frequency * 0.8) + time_offset * 0.5) * 0.2;
	
	// Combine waves
	float combined_wave = (wave1 + wave2 + wave3) * vertical_gradient;
	
	// Apply scrolling effect
	vec2 scroll = scroll_speed * TIME;
	float noise = sin((UV.x + scroll.x) * 10.0) * cos((UV.y + scroll.y) * 8.0);
	
	// Create distortion offset
	vec2 distortion = vec2(
		combined_wave + noise * 0.3,
		combined_wave * 0.5 + noise * 0.2
	) * distortion_strength;
	
	// Sample the screen texture with distortion
	vec4 screen_color = texture(SCREEN_TEXTURE, uv + distortion);
	
	// Add subtle warm tint to distorted areas
	float distortion_intensity = length(distortion) * 20.0;
	vec3 heat_tint = vec3(1.0, 0.9, 0.8);
	screen_color.rgb = mix(screen_color.rgb, screen_color.rgb * heat_tint, distortion_intensity * 0.1);
	
	COLOR = screen_color;
}
