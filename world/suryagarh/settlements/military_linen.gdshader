shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 float thread=sin(p.x*820.0)*sin(p.z*820.0);
 float wear=sin(p.x*31.0+p.z*17.0)*sin(p.z*43.0)*.018;
 ALBEDO=tint.rgb*(.97+wear+thread*.018);
 ROUGHNESS=.96;
}
