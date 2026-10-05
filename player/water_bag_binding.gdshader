shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.24, 0.115, 0.055, 1.0);
uniform float cloth_support = 0.0;
void vertex() {
 VERTEX.z += cloth_support * smoothstep(0.0, 1.0, clamp((0.41 - VERTEX.y) / 0.29, 0.0, 1.0));
}
void fragment() { ALBEDO = base_color.rgb; ROUGHNESS = 0.94; }
