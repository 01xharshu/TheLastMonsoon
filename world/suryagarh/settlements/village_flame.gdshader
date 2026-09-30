shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform float phase = 0.0;
void vertex() {
	float tip = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	VERTEX.x += sin(TIME * 8.0 + phase + tip * 5.0) * tip * 0.12;
	VERTEX.z += cos(TIME * 6.7 + phase + tip * 3.0) * tip * 0.09;
	VERTEX.y *= 0.90 + 0.10 * sin(TIME * 9.0 + phase);
}
void fragment() {
	float band = sin(UV.y * 30.0 - TIME * 11.0 + phase) * sin(UV.x * 21.0 + TIME * 4.0);
	vec3 color = mix(vec3(1.0,0.20,0.018),vec3(1.0,0.75,0.17),clamp(UV.y + band * 0.18,0.0,1.0));
	ALBEDO = color;
	EMISSION = color * 2.0;
	ALPHA = 0.64 + 0.18 * band;
}
