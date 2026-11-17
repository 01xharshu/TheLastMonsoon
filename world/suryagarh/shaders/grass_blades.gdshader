shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float fade_start = 48.0;
uniform float fade_end = 70.0;
varying float patch_tint;
varying float path_clearance;
uniform bool worn_path_enabled = false;
uniform sampler2D worn_path_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec4 worn_path_rect = vec4(0.0);
global uniform vec3 world_wind;
global uniform vec4 grass_vehicle_0;
global uniform vec4 grass_vehicle_1;
global uniform vec4 grass_vehicle_2;
global uniform vec4 grass_vehicle_3;
vec3 vehicle_bend(vec3 root, vec4 vehicle) {
	// Inactive emitters are common; skip four radius/falloff evaluations.
	if (vehicle.w == 0.0) { return vec3(0.0); }
	vec2 away = root.xz-vehicle.xz;
	// The falloff is exactly zero outside this finite wake volume.
	if (dot(away, away) >= 64.0 || abs(root.y-vehicle.y) >= 3.5) { return vec3(0.0); }
	float radius = length(away);
	float influence = (1.0-smoothstep(1.5,8.0,radius))*vehicle.w;
	influence *= 1.0-smoothstep(1.5,3.5,abs(root.y-vehicle.y));
	return vec3(away.x/max(radius,0.1),-0.3,away.y/max(radius,0.1))*influence;
}
void vertex() {
	vec3 rooted = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float distance_to_camera = distance(rooted,CAMERA_POSITION_WORLD);
	float fade = 1.0-smoothstep(fade_start,fade_end,distance_to_camera);
	float weight = UV.y;
 path_clearance=0.0;
 if (worn_path_enabled) {
  vec2 root_xz=MODEL_MATRIX[3].xz;
  vec2 mask_uv=(root_xz-worn_path_rect.xy)/max(worn_path_rect.zw,vec2(0.001));
  if (all(greaterThanEqual(mask_uv,vec2(0.0))) && all(lessThanEqual(mask_uv,vec2(1.0)))) {
   path_clearance=textureLod(worn_path_mask,mask_uv,0.0).r;
  }
 }
 fade*=1.0-path_clearance;
	VERTEX.y *= fade;
	if (fade > 0.0) {
		float breeze = sin(world_wind.y*1.7+rooted.x*.73+rooted.z*.51);
		mat3 world_to_local = inverse(mat3(MODEL_MATRIX));
		vec3 drift = world_to_local * vec3(world_wind.x,0.0,world_wind.z);
		float gust = 0.78+0.22*sin(world_wind.y*0.71-rooted.x*0.015-rooted.z*0.011);
		float stalk_height = length(MODEL_MATRIX[1].xyz);
		VERTEX += drift*breeze*gust*0.018*clamp(stalk_height,1.0,4.0)*weight*weight*fade;
		vec3 wake = vehicle_bend(rooted,grass_vehicle_0)+vehicle_bend(rooted,grass_vehicle_1)+vehicle_bend(rooted,grass_vehicle_2)+vehicle_bend(rooted,grass_vehicle_3);
		VERTEX += world_to_local*wake*min(stalk_height*0.13,0.65)*weight*weight*fade;
	}
	patch_tint = 0.5+0.5*sin(rooted.x*.57+sin(rooted.z*.39));
}
void fragment() {
 if (path_clearance>0.98) { discard; }
	vec3 blade = COLOR.rgb * mix(0.60,1.10,smoothstep(0.0,0.8,UV.y));
	ALBEDO = mix(blade,blade*vec3(1.18,1.02,0.78),patch_tint*0.32);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
