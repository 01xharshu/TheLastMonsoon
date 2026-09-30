shader_type spatial;
render_mode diffuse_burley;

uniform vec4 stone_color : source_color = vec4(0.53, 0.49, 0.40, 1.0);
uniform float building_grade = 0.0;
varying vec3 masonry_position;
varying vec3 masonry_normal;

float block_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	masonry_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masonry_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = abs(normalize(masonry_normal));
	vec2 face = masonry_position.xy;
	if (n.x > n.z && n.x > n.y) face = masonry_position.zy;
	if (n.y > max(n.x, n.z)) face = masonry_position.xz;
	float row = floor(face.y / 0.28);
	vec2 grid = vec2((face.x + mod(row, 2.0) * 0.31) / 0.62, face.y / 0.28);
	vec2 cell = floor(grid);
	vec2 edge = min(fract(grid), 1.0 - fract(grid)) * vec2(0.62, 0.28);
	float mortar = 1.0 - smoothstep(0.005, 0.012, min(edge.x, edge.y));
	float variation = 0.90 + 0.16 * block_hash(cell);
	float grain = sin(face.x * 79.0 + face.y * 27.0) * sin(face.y * 91.0 - face.x * 13.0);
	vec3 stone = stone_color.rgb * (variation + grain * 0.018);
	vec3 joint = stone_color.rgb * 0.76;
	float lower_damp = 1.0 - smoothstep(-2.7, 0.7, masonry_position.y - building_grade);
	ALBEDO = mix(stone, joint, mortar) * (1.0 - lower_damp * 0.13);
	ROUGHNESS = mix(0.86, 0.98, mortar);
}
