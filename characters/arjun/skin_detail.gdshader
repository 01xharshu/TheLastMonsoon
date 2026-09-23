shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D base_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D source_skin : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 anatomical_position;
float noise3(vec3 p){return fract(sin(dot(floor(p),vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){anatomical_position=VERTEX;}
void fragment(){
 vec3 original=texture(source_skin,UV2).rgb;
 vec4 pigment=texture(base_atlas,UV);
 vec3 refined=mix(pigment.rgb,original*vec3(.44,.35,.30),.55);
 float patch=noise3(anatomical_position*34.0);
 float pore=noise3(anatomical_position*460.0);
 float pore_x=noise3((anatomical_position+vec3(.002,0.0,0.0))*460.0);
 float pore_y=noise3((anatomical_position+vec3(0.0,.002,0.0))*460.0);
 ALBEDO=refined*(.965+.052*patch+.024*pore);
 NORMAL_MAP=normalize(vec3((pore_x-pore)*.055,(pore_y-pore)*.055,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.17;
 ROUGHNESS=.66+.065*patch;
 SPECULAR=.43;
 SSS_STRENGTH=.07;
}
