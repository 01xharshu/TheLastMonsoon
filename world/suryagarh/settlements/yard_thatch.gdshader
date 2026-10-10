shader_type spatial;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
 float phase=local_point.z*260.0+sin(local_point.x*23.0)*1.7;
 float fibers=sin(phase)*(.5/(1.0+fwidth(phase)))+.5;
 float bundles=sin(local_point.z*35.0)*.5+.5;
 ALBEDO=mix(vec3(.25,.19,.085),vec3(.48,.38,.17),fibers*.45+bundles*.25);
 ROUGHNESS=.97;
 SPECULAR=.12;
}
