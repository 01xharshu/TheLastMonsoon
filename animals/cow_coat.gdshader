shader_type spatial;
render_mode cull_back;
uniform vec4 base_color:source_color=vec4(.46,.445,.395,1.0);
uniform bool vertex_coat=false;
varying vec3 coat_position;
void vertex(){coat_position=VERTEX;}
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment(){
 // Stable coat colour also covers exporters that drop COLOR_0 at rendering.
 float variation=(noise3(coat_position*3.1)-.5)*.30+(noise3(coat_position*12.0)-.5)*.075;
 float neck_shade=1.0-smoothstep(-1.5,-.55,coat_position.z);
 vec3 pigment=mix(base_color.rgb,COLOR.rgb,vertex_coat?.30:0.0);
 float dorsal=smoothstep(1.0,1.52,coat_position.y);
 float cheek=exp(-pow((coat_position.z+1.30)*4.0,2.0))*smoothstep(.10,.19,abs(coat_position.x));
 vec3 base=pigment*(1.0+variation-neck_shade*.23-dorsal*.055-cheek*.09);
 float fleck=noise3(coat_position*65.0);
 base*=1.0+(fleck-.5)*.045;
 float hair=sin(coat_position.y*1350.0+sin(coat_position.z*33.0)*2.0)*sin(coat_position.x*650.0+coat_position.z*55.0);
 float filter_width=max(length(dFdx(coat_position)),length(dFdy(coat_position)));
 float hair_weight=1.0-smoothstep(.0008,.005,filter_width);
 float dust=1.0-smoothstep(.07,.45,coat_position.y);
 ALBEDO=mix(base,vec3(.31,.25,.17),dust*.16)*(1.0+hair*.035*hair_weight);
 ROUGHNESS=mix(.80,.93,noise3(coat_position*6.0));SPECULAR=.22;
 vec3 dx=dFdx(VERTEX);vec3 dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL);vec3 ry=cross(NORMAL,dx);
 float det=dot(dx,rx);float height=hair*hair_weight*.000075;
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)/max(abs(det),.000001)*sign(det);
 NORMAL=normalize(NORMAL-gradient);
}
