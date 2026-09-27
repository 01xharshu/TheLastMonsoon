shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 rock_color : source_color = vec4(0.49, 0.47, 0.42, 1.0);
varying vec3 object_position;
void vertex() { object_position = VERTEX; }
void fragment() {
    vec3 p = object_position;
    float variation = sin(p.x * 14.0 + p.z * 3.0) * sin(p.y * 17.0 - p.z * 9.0);
    variation += 0.45 * sin(p.x * 39.0 + p.y * 12.0) * sin(p.z * 31.0);
    ALBEDO = rock_color.rgb * (0.87 + variation * 0.11);
    ROUGHNESS = 1.0;
}
