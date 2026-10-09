shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform bool exclude_moored_ship = false;
uniform vec2 moored_ship_center = vec2(-85.0,680.0);
uniform bool distant_surface = false;
uniform float flow_time = 0.0;
uniform bool boat_present = false;
uniform vec2 boat_center;
uniform float boat_heading = 0.0;
uniform float boat_speed = 0.0;
varying vec3 world_position;
varying float wave_crest;
float river_center(float z){ return 60.0+76.0*sin(z*.0045)+22.0*sin(z*.011); }
float river_half_width(float z){ return 55.0+8.0*sin(z*.008+1.0)+340.0*smoothstep(500.0,850.0,z)+5600.0*smoothstep(850.0,1600.0,z); }
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float water_noise(vec2 p){
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
float waves(vec2 p){
 float cross=p.x-river_center(p.y);
 float edge=1.0-smoothstep(.75,1.05,abs(cross)/river_half_width(p.y));
 float travel=p.y-flow_time*1.25;
 return edge*(sin(travel*.52+cross*.16)*.065+sin(travel*.93-cross*.33)*.028);
}
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float h=waves(p.xz);
 VERTEX.y+=h;p.y+=h;world_position=p;wave_crest=h;
 // Analytic finite difference surface normals, including near-bank damping.
 float dx=(waves(p.xz+vec2(.15,0.0))-waves(p.xz-vec2(.15,0.0)))/.3;
 float dz=(waves(p.xz+vec2(0.0,.15))-waves(p.xz-vec2(0.0,.15)))/.3;
 NORMAL=normalize(vec3(-dx,1.0,-dz));
}
void fragment(){
 vec2 xz=world_position.xz;
 if(distant_surface && xz.y>=-864.0 && xz.y<864.0) discard;
 vec2 boat_local=xz-boat_center;
 boat_local=vec2(cos(boat_heading)*boat_local.x-sin(boat_heading)*boat_local.y,sin(boat_heading)*boat_local.x+cos(boat_heading)*boat_local.y);
 // Preserve the small boat's sealed interior as it heaves with the surface.
 if(boat_present && abs(boat_local.y)<1.95 && abs(boat_local.x)<.40*(1.0-.65*pow(abs(boat_local.y)/1.95,3.0))) discard;

 // Dry, sealed hull: water continues around it instead of rendering through
 // the below-water cargo deck. Matches the fixed merchant hull stations.
 vec2 local_ship=xz-moored_ship_center;
 float z=local_ship.y;
 float ship_beam=0.0;
 if(z>=-27.0 && z<=24.0){
  if(z<-25.0) ship_beam=mix(.12,1.0,(z+27.0)/2.0);
  else if(z<-22.0) ship_beam=mix(1.0,2.8,(z+25.0)/3.0);
  else if(z<-18.0) ship_beam=mix(2.8,4.5,(z+22.0)/4.0);
  else if(z<-13.0) ship_beam=mix(4.5,5.5,(z+18.0)/5.0);
  else if(z<-6.0) ship_beam=mix(5.5,5.9,(z+13.0)/7.0);
  else if(z<4.0) ship_beam=5.9;
  else if(z<13.0) ship_beam=mix(5.9,5.3,(z-4.0)/9.0);
  else if(z<20.0) ship_beam=mix(5.3,4.2,(z-13.0)/7.0);
  else ship_beam=mix(4.2,3.4,(z-20.0)/4.0);
 }
 if(exclude_moored_ship && ship_beam>0.0 && abs(local_ship.x)<ship_beam*.955) discard;
 float cross=xz.x-river_center(xz.y);
 float travel=xz.y-flow_time*1.25;
 float broad=sin(travel*.52+cross*.16);
 vec2 moving=vec2(cross,travel);
 float fine=water_noise(moving*1.35)*2.0-1.0;
 float detail=water_noise(moving*3.7+vec2(29.0,17.0))*2.0-1.0;
 float cross_ripple=water_noise(moving.yx*1.7+vec2(47.0,11.0))*2.0-1.0;
 NORMAL_MAP=normalize(vec3(fine*.095+detail*.025,broad*.05+cross_ripple*.08,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.8;
 float scene_depth=texture(depth_texture,SCREEN_UV).r;
 vec4 scene_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_depth,1.0);
 scene_view.xyz/=max(scene_view.w,.00001);
 float water_depth=max(0.0,-scene_view.z+VERTEX.z);
 float shallow=1.0-exp(-water_depth*.38);
 // Silt-tinted fresh water, with broken moving foam only along shallow contact.
 float shore=(1.0-smoothstep(.05,.65,water_depth));
 float broken=smoothstep(.25,.8,water_noise(moving*1.2));
 float foam=shore*broken*.6;
 float bank_band=1.0-smoothstep(.0,.15,abs(abs(cross)/river_half_width(xz.y)-.9));
 float streak=pow(max(0.0,sin(cross*1.1+sin(travel*.1)*.5)),14.0)*bank_band*.07;
 // A restrained V wake follows a moving hull; idle/moored hulls make no trail.
 float wake_z=boat_local.y*sign(boat_speed);
 float wake_span=abs(wake_z)*.34+.5;
 float wake=boat_present ? (1.0-smoothstep(.08,.35,abs(abs(boat_local.x)-wake_span)))*(1.0-smoothstep(2.0,12.0,wake_z))*smoothstep(1.5,3.0,wake_z)*clamp(abs(boat_speed)/3.0,0.0,1.0) : 0.0;
 foam+=wake*.28+streak;
 float glint=pow(max(0.0,fine*.55+detail*.45),8.0);
 ALBEDO=mix(vec3(.19,.28,.20),vec3(.035,.12,.105),shallow);
 ALBEDO=mix(ALBEDO,vec3(.64,.69,.55),clamp(foam,0.0,.65))+vec3(.025)*glint;
 ALPHA=mix(.35,.88,shallow)+foam*.18;
 float sea_weight=smoothstep(560.0,850.0,xz.y);
 ALPHA=mix(ALPHA,mix(.48,.98,shallow),sea_weight);
 ALBEDO=mix(ALBEDO,vec3(.035,.105,.125),sea_weight*shallow);
 ROUGHNESS=mix(.24,.34,shore);
 SPECULAR=.65;
 METALLIC=0.0;
}
