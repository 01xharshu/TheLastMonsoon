shader_type spatial;
render_mode cull_back;
uniform vec4 base_color:source_color=vec4(.1,.08,.065,1.0);
uniform int surface_kind=0; // muzzle, horn, hoof, inner ear
varying vec3 surface_position;
void vertex(){surface_position=VERTEX;}
float noise3(vec3 p){
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 float n=dot(i,vec3(1.0,57.0,113.0));
 vec4 a=fract(sin(n+vec4(0.0,1.0,57.0,58.0))*43758.5453);
 vec4 b=fract(sin(n+vec4(113.0,114.0,170.0,171.0))*43758.5453);
 return mix(mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y),mix(mix(b.x,b.y,f.x),mix(b.z,b.w,f.x),f.y),f.z);
}
void fragment(){
 vec3 p=surface_position;
 float grain=noise3(p*180.0)-.5;
 float width=max(length(dFdx(p)),length(dFdy(p)));
 float detail=1.0-smoothstep(.001,.007,width);
 float height=grain*detail*.0002;
 vec3 colour=base_color.rgb;
 float rough=.42;float shine=.42;
 if(surface_kind==1){
  float ring=sin(p.y*410.0+noise3(p*27.0)*1.5)*detail;
  colour*=mix(1.12,.48,smoothstep(1.44,1.66,p.y))*(1.0+ring*.06);
  height=ring*.00010;rough=.70;shine=.23;
 }else if(surface_kind==2){
  float striation=sin((p.x+p.z*.22)*800.0)*detail;
  colour*=1.0+grain*.09+striation*.035;
  height+=striation*.00005;rough=.80;shine=.20;
 }else if(surface_kind==3){colour*=1.0+grain*.07;rough=.94;shine=.12;}
 else{colour*=1.0+grain*.15;}
 ALBEDO=colour;ROUGHNESS=rough;SPECULAR=shine;
 vec3 dx=dFdx(VERTEX);vec3 dy=dFdy(VERTEX);vec3 rx=cross(dy,NORMAL);vec3 ry=cross(NORMAL,dx);
 float det=dot(dx,rx);
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)/max(abs(det),.000001)*sign(det);
 NORMAL=normalize(NORMAL-gradient);
}
