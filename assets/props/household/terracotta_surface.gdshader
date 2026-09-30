shader_type spatial;
varying vec3 point;
void vertex() { point=VERTEX; }
void fragment() {
	float grain=fract(sin(dot(floor(point.xz*750.0+point.y*113.0),vec2(12.9898,78.233)))*43758.5453);
	float bands=sin(point.y*410.0)*.025;
	float variation=sin(point.x*19.0+point.y*8.0)*sin(point.z*17.0)*.065;
	ALBEDO=vec3(.43,.20,.095)*(1.0+bands+variation+(grain-.5)*.075);
	ROUGHNESS=.94;
}
