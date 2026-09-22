shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float a = sin(wp.x*2.3 + wp.z*0.8 + TIME*1.3);
	float b = sin(wp.x*0.7-wp.z*3.6+TIME*1.8);
	NORMAL_MAP = normalize(vec3(a*0.11,b*0.07,1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH = 0.65;
	ALBEDO = vec3(0.075,0.13,0.105) + vec3(0.007)*(a*b);
	METALLIC = 0.15;
	ROUGHNESS = 0.22;
	SPECULAR = 0.8;
}
