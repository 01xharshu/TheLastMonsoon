shader_type spatial;
uniform vec4 tint : source_color = vec4(.33,.23,.15,1);
varying vec3 timber_uv;
void vertex(){ timber_uv=UV.xyx; }
void fragment(){
 // Physical metre UVs follow each member's longest axis, independent of world position.
 float drift=sin(timber_uv.x*2.7)+.35*sin(timber_uv.x*7.3);
 float phase=timber_uv.y*145.0+drift*1.2;
 float grain=sin(phase)*(1.0-smoothstep(.4,2.4,fwidth(phase)));
 float fine_phase=timber_uv.y*387.0+drift*2.0;
 float fine=sin(fine_phase)*(1.0-smoothstep(.4,2.4,fwidth(fine_phase)));
 float tone=.97+.035*grain+.012*fine+.025*sin(timber_uv.x*.71);
 ALBEDO=tint.rgb*tone;
 ROUGHNESS=.72+.045*grain;
}
