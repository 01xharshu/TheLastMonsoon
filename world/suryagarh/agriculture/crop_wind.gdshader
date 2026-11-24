shader_type spatial;
render_mode cull_disabled;
varying vec3 tone;
void vertex() {
 tone=COLOR.rgb*(0.84+INSTANCE_CUSTOM.x*0.24);
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float weight=pow(clamp(VERTEX.y/3.6,0.0,1.0),1.7);
 VERTEX.x+=sin(TIME*1.25+p.x*0.18+p.z*0.11+INSTANCE_CUSTOM.y*6.283)*0.16*weight;
 VERTEX.z+=cos(TIME*0.9+p.z*0.15)*0.08*weight;
}
void fragment() {
 ALBEDO=tone;
 ROUGHNESS=0.88;
 BACKLIGHT=tone*0.18;
}
