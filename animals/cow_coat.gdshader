shader_type spatial;
render_mode cull_back;
uniform vec4 base_color:source_color=vec4(.69,.66,.58,1.0);
uniform bool vertex_coat=false;
varying vec3 coat_position;
void vertex(){coat_position=VERTEX;}
void fragment(){
 // Stable coat colour also covers exporters that drop COLOR_0 at rendering.
 float variation=sin(coat_position.y*7.0+coat_position.z*5.0)*.025+sin(coat_position.x*19.0)*.012;
 float neck_shade=1.0-smoothstep(-1.5,-.55,coat_position.z);
 vec3 base=base_color.rgb*(1.0+variation-neck_shade*.09);
 float hair=sin(coat_position.y*1350.0+sin(coat_position.z*33.0)*2.0)*sin(coat_position.x*650.0+coat_position.z*55.0);
 float filter_width=max(length(dFdx(coat_position)),length(dFdy(coat_position)));
 float hair_weight=1.0-smoothstep(.0008,.005,filter_width);
 float dust=1.0-smoothstep(.07,.45,coat_position.y);
 ALBEDO=mix(base,vec3(.31,.25,.17),dust*.16)*(1.0+hair*.035*hair_weight);
 ROUGHNESS=.93;SPECULAR=.18;
 vec3 dx=dFdx(VERTEX);vec3 dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL);vec3 ry=cross(NORMAL,dx);
 float det=dot(dx,rx);float height=hair*hair_weight*.000075;
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)/max(abs(det),.000001)*sign(det);
 NORMAL=normalize(NORMAL-gradient);
}
