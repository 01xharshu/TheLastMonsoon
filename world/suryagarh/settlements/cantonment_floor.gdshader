shader_type spatial;
uniform vec4 tint: source_color = vec4(.39,.38,.34,1.0);
varying vec3 p;
float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 q=p.xz/vec2(.75,.6);
 vec2 edge=min(fract(q),1.0-fract(q));
 float joint=1.0-smoothstep(.006,.02,min(edge.x,edge.y));
 float grain=hash(floor(p.xz*100.0));
 vec3 stone=tint.rgb*(.88+.18*hash(floor(q))+.04*grain);
 ALBEDO=mix(stone,tint.rgb*.65,joint*.7);
 ROUGHNESS=.94;
}
