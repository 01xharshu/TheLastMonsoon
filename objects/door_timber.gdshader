shader_type spatial;
uniform vec4 tint : source_color = vec4(.27,.16,.085,1.0);
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 float grain = sin(local_pos.x*145.0+sin(local_pos.y*3.1)*1.2)*.025;
 float broad = sin(local_pos.x*23.0+sin(local_pos.y*.9)*.6)*.07;
 float weather = hash(floor(local_pos.xy*vec2(22.0,5.0)))*.04;
 ALBEDO = tint.rgb*(1.0+broad+grain+weather);
 ROUGHNESS = .88;
}
