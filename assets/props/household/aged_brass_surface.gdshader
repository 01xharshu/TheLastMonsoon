shader_type spatial;
varying vec3 point;
void vertex() { point=VERTEX; }
void fragment() {
	float patina=sin(point.x*125.0+sin(point.z*92.0))*sin(point.z*80.0+point.y*60.0)*.5+.5;
	ALBEDO=mix(vec3(.46,.29,.10),vec3(.19,.20,.13),smoothstep(.55,.92,patina)*.45);
	METALLIC=.72;
	ROUGHNESS=.48+patina*.15;
}
