shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(.64,.56,.42,1.0);
uniform float courses = 0.0;
varying vec3 local_position;
float grain(vec3 p) {return fract(sin(dot(floor(p),vec3(12.9898,78.233,39.425)))*43758.5453);}
void vertex(){local_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=local_position;
 float weather=grain(p*1.8)*.10+grain(p*62.0)*.035;
 float mortar=0.0;
 if(courses>0.0){
  vec2 uv=abs(NORMAL.z)>abs(NORMAL.x)?p.xy:p.zy;
  float row=floor(uv.y*5.0);
  vec2 brick=fract(vec2(uv.x*2.2+mod(row,2.0)*.5,uv.y*5.0));
  mortar=(1.0-smoothstep(.025,.065,min(brick.x,brick.y)))*courses;
 }
 ALBEDO=mix(tint.rgb*(.9+weather),vec3(.42,.38,.30),mortar*.65);
 ROUGHNESS=.92;
}
