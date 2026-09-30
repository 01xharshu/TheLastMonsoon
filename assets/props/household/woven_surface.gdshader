shader_type spatial;
varying vec3 point;
void vertex() { point=VERTEX; }
void fragment() {
	float warp=sin(point.x*1400.0)*sin(point.y*1400.0);
	float fleck=fract(sin(dot(floor(point.xy*650.0),vec2(12.9898,78.233)))*43758.5453);
	ALBEDO=vec3(.53,.41,.25)*(.90+warp*.065+fleck*.14);
	ROUGHNESS=.96;
}
