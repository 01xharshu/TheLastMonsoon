shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float a = sin(wp.x*2.3 + wp.z*0.8 + sin(wp.z*0.47+TIME*0.4)*1.8 + TIME*1.3);
	float b = sin(wp.x*0.7-wp.z*3.6+cos(wp.x*0.57)*2.0+TIME*1.8);
	NORMAL_MAP = normalize(vec3(a*0.065,b*0.045,1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH = 0.65;
	ALBEDO = vec3(0.075,0.13,0.105) + vec3(0.007)*(a*b);
	METALLIC = 0.15;
	ROUGHNESS = 0.3;
	SPECULAR = 0.8;
}
