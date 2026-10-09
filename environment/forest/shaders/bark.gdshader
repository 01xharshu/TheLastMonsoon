shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D bark_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float macro_variation : hint_range(0.0, 0.4) = 0.14;
varying vec2 bark_uv;
varying vec3 world_position;
varying float base_height;
float hash31(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	bark_uv = UV + vec2(hash31(origin), hash31(origin + vec3(17.0)));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base_height = VERTEX.y;
}
void fragment() {
	vec3 cell = floor(world_position * 0.4);
	vec3 f = fract(world_position * 0.4);
	f = f * f * (3.0 - 2.0 * f);
	float variation = mix(mix(hash31(cell), hash31(cell + vec3(1,0,0)), f.x),
		mix(hash31(cell + vec3(0,1,0)), hash31(cell + vec3(1,1,0)), f.x), f.y);
	vec3 albedo = texture(bark_color, bark_uv).rgb;
	float damp = (1.0 - smoothstep(0.0, 1.4, base_height)) * (0.3 + variation * 0.4);
	ALBEDO = albedo * (1.0 + (variation - 0.5) * macro_variation) * mix(vec3(1.0), vec3(0.77,0.89,0.68), damp);
	NORMAL_MAP = texture(bark_normal, bark_uv).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = clamp(texture(bark_roughness, bark_uv).r - damp * 0.08, 0.5, 1.0);
	SPECULAR = 0.22;
}
