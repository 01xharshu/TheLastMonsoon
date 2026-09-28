shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D soil_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 path_points[8];
uniform int path_point_count = 0;
uniform float path_radius = 3.0;
uniform float path_feather = 2.0;
uniform float surface_seed = 1857.0;
uniform float macro_variation : hint_range(0.0, 0.5) = 0.17;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float corridor_distance(vec2 p) {
	float nearest = 100000.0;
	for (int i = 0; i < 7; i++) {
		if (i >= path_point_count - 1) { break; }
		vec2 a = path_points[i];
		vec2 ab = path_points[i + 1] - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		nearest = min(nearest, distance(p, a + ab * t));
	}
	return nearest;
}

void fragment() {
	vec2 p = world_position.xz;
	float micro = value_noise(p * 0.38 + vec2(surface_seed * 0.001));
	float macro = value_noise(p * 0.045 + vec2(surface_seed * 0.01));
	float pockets = value_noise(p * 0.13 - vec2(surface_seed * 0.003));
	float path = 1.0 - smoothstep(path_radius * 0.7, path_radius + max(path_feather, 0.001), corridor_distance(p));
	float soil_patch = smoothstep(0.38, 0.67, pockets + (micro - 0.5) * 0.18);
	float moss = smoothstep(0.48, 0.76, macro * 0.7 + pockets * 0.3) * (1.0 - path);
	float grass = clamp(0.60 + macro * 0.36 - soil_patch * 0.24 - path * 0.86, 0.0, 0.88);
	float grit = smoothstep(0.68, 0.86, micro * 0.62 + pockets * 0.38) * 0.24;
	vec3 soil = texture(soil_color, p / 3.2).rgb;
	vec3 green = texture(grass_color, p / 6.5).rgb;
	vec3 stone = texture(rock_color, p / 4.0).rgb;
	vec3 leaf_litter = soil * vec3(0.72, 0.70, 0.52);
	vec3 base = mix(soil, green * vec3(0.48, 0.88, 0.40), grass);
	base = mix(base, green * vec3(0.40, 0.60, 0.39), moss * 0.42);
	base = mix(base, leaf_litter, soil_patch * 0.35 * (1.0 - path));
	base = mix(base, stone * vec3(0.68), grit);
	base = mix(base, soil * vec3(0.95, 0.87, 0.69), path * 0.72);
	base *= 1.0 + (macro - 0.5) * macro_variation;
	ALBEDO = base;
	ROUGHNESS = clamp(0.86 + soil_patch * 0.07 - moss * 0.15 + (macro - 0.5) * 0.07, 0.65, 0.98);
	SPECULAR = 0.2;
	vec3 soil_n = texture(soil_normal, p / 3.2).rgb;
	vec3 grass_n = texture(grass_normal, p / 6.5).rgb;
	vec3 rock_n = texture(rock_normal, p / 4.0).rgb;
	NORMAL_MAP = mix(mix(soil_n, grass_n, grass), rock_n, grit);
	NORMAL_MAP_DEPTH = 0.68;
}
