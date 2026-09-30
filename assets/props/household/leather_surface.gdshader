shader_type spatial;
varying vec3 point;
void vertex() { point=VERTEX; }
void fragment() {
	float grain=fract(sin(dot(floor(point.xy*900.0),vec2(12.9898,78.233)))*43758.5453);
	float wear=sin(point.x*42.0+sin(point.y*24.0))*sin(point.y*31.0)*.065;
	ALBEDO=vec3(.27,.125,.055)*(1.0+wear+(grain-.5)*.10);
	ROUGHNESS=.78;
}
