shader_type spatial;
varying vec3 point;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { point=VERTEX; }
void fragment() {
	float toast=smoothstep(.56,.73,noise(point.xz*85.0)+noise(point.xz*170.0)*.16);
	float charred=smoothstep(.78,.9,noise(point.xz*85.0)+noise(point.xz*170.0)*.16);
	vec3 dough=vec3(.68,.46,.23)*(0.92+noise(point.xz*900.0)*.13);
	ALBEDO=mix(mix(dough,vec3(.28,.12,.035),toast),vec3(.10,.045,.014),charred);
	ROUGHNESS=.95;
}
