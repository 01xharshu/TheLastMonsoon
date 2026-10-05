shader_type spatial;
uniform vec4 tint: source_color = vec4(.55,.43,.20,1.0);
varying vec3 p;
float hash(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float strand=hash(floor(vec3(p.x*2.0,p.y*95.0,p.z*95.0)));
 float fleck=hash(floor(p*85.0));
 float patch=hash(floor(p*4.0));
 ALBEDO=tint.rgb*(.86+.16*strand+.055*fleck+.055*patch);
 ROUGHNESS=.98;
}
