shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
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
 float u=sin(xz.x*.62+TIME*1.3+xz.y*.22+sin(xz.y*.14)*1.3);
 float v=sin(xz.y*.38-TIME*1.05-xz.x*.23+sin(xz.x*.12)*.8);
 float small=sin(xz.x*2.7+xz.y*1.8-TIME*2.7);
 NORMAL_MAP=normalize(vec3(u*.047+small*.01,v*.045,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.75;
 float scene_depth=texture(depth_texture,SCREEN_UV).r;
 vec4 scene_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_depth,1.0);
 scene_view.xyz/=max(scene_view.w,.00001);
 float water_depth=max(0.0,-scene_view.z+VERTEX.z);
 float shallow=clamp(water_depth/5.5,0.0,1.0);
 vec3 shallow_color=vec3(.15,.33,.27);
 vec3 deep_color=vec3(.025,.105,.105);
 float foam=(1.0-smoothstep(.02,.35,water_depth))*(.2+.15*max(u*v,0.0));
 ALBEDO=mix(shallow_color,deep_color,shallow)+vec3(.12,.14,.11)*foam+vec3(.025)*max(small,0.0);
 ALPHA=mix(.26,.71,shallow)+foam*.25;
 ROUGHNESS=.19;
 SPECULAR=.8;
 METALLIC=0.0;
}
