shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform bool use_roughness_texture = false;
uniform vec2 foliage_uv_scale = vec2(1.0);
uniform vec2 foliage_uv_offset = vec2(0.0);
uniform bool use_albedo_texture = false;
uniform bool use_normal_texture = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.45;
uniform bool wind_uv_reversed = false;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.25;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.7;
uniform vec2 wind_direction = vec2(0.9, 0.4);

global uniform vec3 world_wind;
void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	float height_weight = wind_uv_reversed ? 1.0 - UV.y : UV.y;
	float tip_weight = pow(clamp(height_weight, 0.0, 1.0), 2.0);
	float phase = dot(world_origin.xz, vec2(0.31, 0.47));
	float broad = sin(world_wind.y * wind_speed + phase);
	float fine = sin(world_wind.y * wind_speed * 1.83 + phase * 1.7 + VERTEX.y * 2.0);
	vec2 direction = normalize(world_wind.xz + vec2(0.001));
	vec3 drift = inverse(mat3(MODEL_MATRIX)) * vec3(direction.x,0.0,direction.y);
	float gust = 0.78+0.22*sin(world_wind.y*0.71-world_origin.x*0.015-world_origin.z*0.011);
	VERTEX += drift * gust * (broad * 0.7 + fine * 0.3) * wind_strength * length(world_wind.xz) * 0.4 * tip_weight;
}

void fragment() {
	vec2 foliage_uv = UV * foliage_uv_scale + foliage_uv_offset;
	vec4 surface_color = COLOR * tint;
	if (use_albedo_texture) {
		surface_color *= texture(albedo_texture, foliage_uv);
	}
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ALBEDO = surface_color.rgb;
	ALPHA = surface_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = use_roughness_texture ? texture(roughness_texture, foliage_uv).g : roughness_value;
	SPECULAR = 0.18;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, foliage_uv).rgb;
		NORMAL_MAP_DEPTH = 0.65;
	}
}
