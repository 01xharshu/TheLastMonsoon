shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform bool exclude_moored_ship = false;
uniform vec2 moored_ship_center = vec2(-85.0,680.0);
varying vec3 world_position;
varying float wave_crest;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float long_wave=sin(p.z*.34-TIME*1.35+p.x*.10)*.045;
 float crossed=sin(p.x*.81+TIME*1.7+p.z*.17)*.024;
 VERTEX.y+=long_wave+crossed;
 p.y+=long_wave+crossed;
 world_position=p;
 wave_crest=long_wave+crossed;
}
void fragment(){
 vec2 xz=world_position.xz;
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
 float u=sin(xz.x*.62+TIME*1.3+xz.y*.22+sin(xz.y*.14)*1.3);
 float v=sin(xz.y*.38-TIME*1.05-xz.x*.23+sin(xz.x*.12)*.8);
 float small=sin(xz.x*2.7+xz.y*1.8-TIME*2.7);
 float detail=sin(xz.x*5.1-TIME*3.1+xz.y*2.2)*sin(xz.y*4.3+TIME*2.4);
 NORMAL_MAP=normalize(vec3(u*.047+small*.01+detail*.008,v*.045+detail*.006,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.75;
 float scene_depth=texture(depth_texture,SCREEN_UV).r;
 vec4 scene_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_depth,1.0);
 scene_view.xyz/=max(scene_view.w,.00001);
 float water_depth=max(0.0,-scene_view.z+VERTEX.z);
 float shallow=clamp(water_depth/5.5,0.0,1.0);
 vec3 shallow_color=vec3(.15,.33,.27);
 vec3 deep_color=vec3(.025,.105,.105);
 float foam=(1.0-smoothstep(.02,.35,water_depth))*(.2+.15*max(u*v,0.0));
 float current=sin(xz.y*.12-TIME*.7+sin(xz.x*.07)*2.0);
 float glint=pow(max(0.0,small*.55+detail*.3+current*.15),6.0);
 ALBEDO=mix(shallow_color,deep_color,shallow)+vec3(.12,.14,.11)*foam+vec3(.025)*max(small,0.0)+vec3(.035,.045,.04)*glint;
 ALPHA=mix(.26,.71,shallow)+foam*.25;
 // The fresh river stays translucent. Deep tidal water gradually becomes
 // opaque toward the scenic sea, avoiding a visible tiled bed at the horizon.
 float sea_weight=smoothstep(560.0,850.0,xz.y);
 ALPHA=mix(ALPHA,mix(.42,.98,shallow),sea_weight);
 ALBEDO=mix(ALBEDO,vec3(.035,.105,.125)+vec3(.02)*glint,sea_weight*shallow);
 ROUGHNESS=.19;
 SPECULAR=.8;
 METALLIC=0.0;
}
