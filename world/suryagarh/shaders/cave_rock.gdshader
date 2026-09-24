shader_type spatial;
render_mode cull_disabled;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 stone_tint : source_color = vec3(0.72, 0.69, 0.62);
void fragment() {
	vec3 n = abs(normalize(NORMAL));
	vec3 weights = pow(n, vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / 3.5;
	vec3 x = texture(rock_albedo, p.zy).rgb;
	vec3 y = texture(rock_albedo, p.xz).rgb;
	vec3 z = texture(rock_albedo, p.xy).rgb;
	ALBEDO = (x * weights.x + y * weights.y + z * weights.z) * stone_tint;
	ROUGHNESS = 0.98;
}
