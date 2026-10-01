shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.78,0.75,0.66,1.0);
uniform float grade = 0.0;
uniform bool paving = false;
varying vec3 world_position;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
 vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=world_position;
 float cloud=noise(p*1.15);
 float fine=noise(p*58.0);
 vec3 color=tint.rgb*(0.94+cloud*0.09+fine*0.025);
 if(paving){
  vec2 cell=p.xz/0.72;
  vec2 edge=min(fract(cell),1.0-fract(cell));
  float joint=1.0-smoothstep(0.007,0.019,min(edge.x,edge.y));
  color*=0.94+hash(vec3(floor(cell),0))*0.10;
  color=mix(color,tint.rgb*0.62,joint*0.45);
 }else{
  float damp=(1.0-smoothstep(0.0,0.85,p.y-grade))*(0.65+cloud*0.35);
  color=mix(color,color*vec3(0.76,0.79,0.73),damp*0.45);
 }
 ALBEDO=color;
 ROUGHNESS=0.88+fine*0.08;
}
