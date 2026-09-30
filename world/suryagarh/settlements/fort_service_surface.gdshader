shader_type spatial;
uniform vec4 tint : source_color;
uniform int kind = 0;
varying vec3 p;
float hash(vec2 x) { return fract(sin(dot(x,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 x) { vec2 i=floor(x); vec2 f=fract(x); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float weather=noise(p.xz*.75)+noise(p.xy*2.8)*.25;
 vec3 color=tint.rgb*(.90+weather*.15);
 if(kind==1) {
  vec2 q=p.xz/vec2(.78,.56);
  q.x+=mod(floor(q.y),2.0)*.5;
  vec2 edge=min(fract(q),1.0-fract(q));
  float joint=1.0-smoothstep(.012,.023,min(edge.x,edge.y));
  color*=.88+hash(floor(q))*.22;
  color=mix(color,tint.rgb*.57,joint);
 } else {
  float damp=(1.0-smoothstep(8.8,9.5,p.y))*(.04+noise(p.xz*3.0)*.08);
  color*=1.0-damp;
 }
 ALBEDO=color;
 ROUGHNESS=.94;
}
