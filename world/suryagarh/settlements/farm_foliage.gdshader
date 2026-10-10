shader_type spatial;
render_mode cull_disabled;
varying vec3 world_point;
global uniform vec3 world_wind;
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float gust=sin(world_wind.y*1.3+world_point.x*.42+world_point.z*.31);
 vec3 drift=inverse(mat3(MODEL_MATRIX))*vec3(world_wind.x,0.0,world_wind.z);
 VERTEX+=drift*gust*UV.y*UV.y*.008;
}
void fragment() {
 ALBEDO=COLOR.rgb*mix(.72,1.12,UV.y);
 ROUGHNESS=.88;
 SPECULAR=.18;
 BACKLIGHT=COLOR.rgb*.16;
}
