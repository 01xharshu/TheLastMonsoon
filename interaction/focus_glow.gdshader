shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform mat4 mesh_to_focus;
uniform vec3 focus_min = vec3(0.0);
uniform vec3 focus_size = vec3(1.0);
varying float shine_coordinate;
void vertex() {
	vec3 point = (mesh_to_focus * vec4(VERTEX, 1.0)).xyz;
	vec3 unit_point = (point - focus_min) / max(focus_size, vec3(0.001));
	shine_coordinate = dot(unit_point, vec3(0.42, 0.42, 0.16));
}
void fragment() {
	// One narrow diagonal sweep, followed by a quiet interval. No constant tint.
	float travel = mod(TIME, 2.8) / 1.5;
	float band = 1.0 - smoothstep(0.015, 0.11, abs(shine_coordinate - (travel * 1.4 - 0.2)));
	ALBEDO = glow_color.rgb * band * 0.85;
	ALPHA = band * 0.8;
}
