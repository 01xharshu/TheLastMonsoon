shader_type spatial;
render_mode cull_disabled;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 a=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1,1)),f.x),f.y);}
void fragment(){
 float across=abs((UV.x-.5)*14.0);
 float rut=1.0-smoothstep(.10,.29,min(abs(across-1.12),abs(across-3.75)));
 float grain=noise(at.xz*1.3);
 ALBEDO=texture(earth_texture,at.xz/2.2).rgb*mix(vec3(.88,.78,.61),vec3(.58,.46,.30),rut*.55)*mix(.82,1.08,grain);
 NORMAL_MAP=texture(earth_normal,at.xz/2.2).rgb;NORMAL_MAP_DEPTH=.6;
 ROUGHNESS=.96;SPECULAR=.12;
 float shoulder=5.9+noise(at.xz*.55)*.5;
 ALPHA=1.0-smoothstep(shoulder,6.98,across);
}
