shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float fade_start = 48.0;
uniform float fade_end = 70.0;
varying float patch_tint;
global uniform vec3 world_wind;
void vertex() {
	vec3 rooted = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float distance_to_camera = distance(rooted,CAMERA_POSITION_WORLD);
	float fade = 1.0-smoothstep(fade_start,fade_end,distance_to_camera);
	float weight = UV.y;
	float breeze = sin(world_wind.y*1.7+rooted.x*.73+rooted.z*.51);
	VERTEX.y *= fade;
	vec3 drift = inverse(mat3(MODEL_MATRIX)) * vec3(world_wind.x,0.0,world_wind.z);
	float gust = 0.78+0.22*sin(world_wind.y*0.71-rooted.x*0.015-rooted.z*0.011);
	VERTEX += drift*breeze*gust*0.018*weight*weight*fade;
	patch_tint = 0.5+0.5*sin(rooted.x*.57+sin(rooted.z*.39));
}
void fragment() {
	vec3 blade = COLOR.rgb * mix(0.60,1.10,smoothstep(0.0,0.8,UV.y));
	ALBEDO = mix(blade,blade*vec3(1.18,1.02,0.78),patch_tint*0.32);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
