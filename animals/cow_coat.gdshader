shader_type spatial;
render_mode cull_back;
uniform vec4 base_color:source_color=vec4(.69,.66,.58,1.0);
uniform bool vertex_coat=false;
varying vec3 coat_position;
void vertex(){coat_position=VERTEX;}
void fragment(){
 vec3 base=vertex_coat?COLOR.rgb:base_color.rgb;
 float hair=sin(coat_position.y*1350.0+sin(coat_position.z*33.0)*2.0)*sin(coat_position.x*650.0+coat_position.z*55.0);
 float filter_width=max(length(dFdx(coat_position)),length(dFdy(coat_position)));
 float hair_weight=1.0-smoothstep(.0008,.005,filter_width);
 float dust=1.0-smoothstep(.07,.45,coat_position.y);
 ALBEDO=mix(base,vec3(.31,.25,.17),dust*.16)*(1.0+hair*.035*hair_weight);
 ROUGHNESS=.93;SPECULAR=.18;
}
