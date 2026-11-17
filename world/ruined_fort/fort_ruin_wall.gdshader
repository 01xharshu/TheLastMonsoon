shader_type spatial;

varying vec3 world_point;
varying vec3 wall_normal;
uniform sampler2D stone_grain : source_color, repeat_enable, filter_linear_mipmap;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_field(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 weight = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1,0)), weight.x),
		mix(hash_cell(cell + vec2(0,1)), hash_cell(cell + vec2(1,1)), weight.x),
		weight.y
	);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wall_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 face = vec2(abs(wall_normal.x) > abs(wall_normal.z) ? world_point.z : world_point.x, world_point.y);
	if (abs(wall_normal.y) > 0.7) {
		face = world_point.xz;
	}
	vec2 crooked = face + vec2(noise_field(face * 4.4), noise_field(face.yx * 5.5)) * 0.06;
	float course = floor(crooked.y / 0.31);
	float block_width = mix(0.53, 0.81, hash_cell(vec2(course, 17.0)));
	vec2 brick = vec2(crooked.x / block_width + hash_cell(vec2(course, 3.0)), crooked.y / 0.31);
	vec2 joints = min(fract(brick), 1.0 - fract(brick));
	float bed = 1.0 - smoothstep(0.022, 0.065, joints.y);
	float joint = 1.0 - smoothstep(0.008, 0.035, joints.x);
	float mortar = max(bed, joint);
	float tint = hash_cell(floor(brick));
	vec3 texture_color = texture(stone_grain, face * 0.7).rgb;
	vec3 stone = mix(vec3(.22,.15,.10), vec3(.48,.39,.29), tint) * (texture_color * .65 + .56);
	vec3 lime = vec3(.57,.48,.34) * (.73 + noise_field(face * 3.9) * .28);
	float plaster = smoothstep(.59,.66,noise_field(face * .65) + noise_field(face * 6.5) * .14);
	float weather = .78 + noise_field(face * .33 + vec2(14,0)) * .22;
	ALBEDO = mix(mix(stone, vec3(.22,.18,.13), mortar * .8), lime, plaster) * weather;
	ROUGHNESS = .98;
}
