shader_type canvas_item;

// Half extents in normalized UV space.
// 0.5 means full texture visible; lower values clip to a tighter centered box.
uniform vec2 half_extent_uv = vec2(0.5, 0.5);

void fragment() {
	vec2 centered = abs(UV - vec2(0.5));
	float inside_x = step(centered.x, half_extent_uv.x);
	float inside_y = step(centered.y, half_extent_uv.y);
	float mask = inside_x * inside_y;
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * mask) * COLOR;
}
