shader_type spatial;
uniform vec4 wood_color : source_color = vec4(.34,.25,.16,1.0);
varying vec3 timber_position;
void vertex() { timber_position = VERTEX; }
void fragment() {
 float waviness = sin(timber_position.z*1.7)*.35+sin(timber_position.z*.37)*.65;
 float grain = sin(timber_position.x*110.0+waviness)*.035;
 float weather = sin(timber_position.z*.55+timber_position.x*3.0)*.055;
 ALBEDO = wood_color.rgb*(1.0+grain+weather);
 ROUGHNESS = .94;
}
