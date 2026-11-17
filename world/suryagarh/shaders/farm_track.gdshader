shader_type spatial;
render_mode cull_disabled;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 a=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1,1)),f.x),f.y);}
void fragment(){
 float across=(UV.x-.5)*4.2;
 float wobble=(noise(vec2(UV.y*.3,4.0))-.5)*.12;
 float rut=1.0-smoothstep(.10,.23,abs(abs(across+wobble)-1.02));
 float wet=smoothstep(.52,.82,(sin(at.x*.11+at.z*.075-1.5)+1.0)*.5);
 float patch=noise(at.xz*.8);
 vec3 soil=texture(earth_texture,at.xz/1.8).rgb;
 ALBEDO=soil*mix(vec3(.78,.68,.49),vec3(.36,.27,.17),wet*.6+rut*.25)*mix(.82,1.12,patch);
 NORMAL_MAP=texture(earth_normal,at.xz/1.8).rgb;NORMAL_MAP_DEPTH=.65;
 ROUGHNESS=mix(.96,.39,wet*(.45+rut*.55));SPECULAR=mix(.12,.38,wet);
 float edge=1.8+(noise(at.xz*2.2)-.5)*.22;
 ALPHA=1.0-smoothstep(edge,2.09,abs(across));
}
