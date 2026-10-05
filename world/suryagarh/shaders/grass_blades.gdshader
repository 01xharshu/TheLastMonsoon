shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float fade_start = 48.0;
uniform float fade_end = 70.0;
varying float patch_tint;
void vertex() {
	vec3 rooted = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float distance_to_camera = distance(rooted,CAMERA_POSITION_WORLD);
	float fade = 1.0-smoothstep(fade_start,fade_end,distance_to_camera);
	float weight = UV.y;
	float breeze = sin(TIME*1.7+rooted.x*.73+rooted.z*.51);
	VERTEX.y *= fade;
	VERTEX.xz += vec2(0.8,0.35)*breeze*0.012*weight*weight*fade;
	patch_tint = 0.5+0.5*sin(rooted.x*.57+sin(rooted.z*.39));
}
void fragment() {
	vec3 blade = COLOR.rgb * mix(0.60,1.10,smoothstep(0.0,0.8,UV.y));
	ALBEDO = mix(blade,blade*vec3(1.18,1.02,0.78),patch_tint*0.32);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
