shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float lane_width = 4.0;
uniform float wheel_wear = 1.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float cross_distance=(UV.x-.5)*lane_width;
 float waviness=(noise(vec2(UV.y*.17,2.4))-.5)*.13;
 float track=1.0-smoothstep(.09,.21,abs(abs(cross_distance+waviness)-.68));
 float shoulder=smoothstep(.60,.99,abs(UV.x-.5)*2.0);
 float grain=noise(world_position.xz*3.2);
 vec3 earth=texture(earth_texture,world_position.xz/3.0).rgb;
 earth*=mix(vec3(.95,.79,.57),vec3(.70,.61,.48),track*wheel_wear*.45);
 ALBEDO=earth*mix(.90,1.08,grain);
 NORMAL_MAP=texture(earth_normal,world_position.xz/3.0).rgb;
 NORMAL_MAP_DEPTH=mix(.20,.52,shoulder);
 ROUGHNESS=.94;
 SPECULAR=.14;
 ALPHA=(1.0-smoothstep(.74+noise(world_position.xz*1.7)*.12,.99,abs(UV.x-.5)*2.0))*.90;
}
