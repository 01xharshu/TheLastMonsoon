shader_type spatial;
uniform vec4 tint: source_color;
uniform int kind=0;
varying vec3 p;
float hash(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 q){vec3 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float coarse=noise(p*1.3),fine=noise(p*65.0);
 vec3 color=tint.rgb*(.86+.18*coarse+.055*fine);
 if(kind==1){
  vec2 q=vec2(p.x+p.z,p.y)/vec2(.27,.085);q.x+=mod(floor(q.y),2.0)*.5;
  vec2 edge=min(fract(q),1.0-fract(q));
  float joint=1.0-smoothstep(.018,.043,min(edge.x,edge.y));
  color*=.85+.25*hash(vec3(floor(q),0));color=mix(color,tint.rgb*.64,joint);
 }else if(kind==2){color*=.82+.22*noise(vec3((p.x+p.z)*8.0,p.y*.6,0))+.08*sin((p.x+p.z)*110.0+coarse*8.0);}
 else if(kind==3){vec2 q=p.xz/vec2(.31,.43);vec2 e=min(fract(q),1.0-fract(q));float joint=1.0-smoothstep(.015,.035,min(e.x,e.y));color=mix(color,tint.rgb*.52,joint);}
 ALBEDO=color;ROUGHNESS=.9;
}
