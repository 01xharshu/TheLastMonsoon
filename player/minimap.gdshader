shader_type canvas_item;
uniform sampler2D terrain : filter_linear, repeat_disable;
uniform vec2 world_center = vec2(0.5);
uniform float world_span = 0.13;
uniform float heading = 0.0;
void fragment() {
	vec2 offset = UV - vec2(0.5);
	if (length(offset) > 0.5) { discard; }
	float c = cos(heading);
	float s = sin(heading);
	vec2 world_offset = vec2(c * offset.x + s * offset.y, -s * offset.x + c * offset.y);
	COLOR = texture(terrain, world_center + world_offset * world_span);
}
