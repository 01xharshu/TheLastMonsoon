shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.67, 0.63, 0.54, 1.0);
varying vec3 object_position;
void vertex() {
    object_position = VERTEX;
}
void fragment() {
    vec3 p = object_position;
    float row = floor(p.y / 0.42);
    vec2 block_uv = vec2((p.x + mod(row, 2.0) * 0.48) / 0.96, p.y / 0.42);
    vec2 seam = min(fract(block_uv), 1.0 - fract(block_uv));
    float mortar = 1.0 - smoothstep(0.015, 0.055, min(seam.x, seam.y));
    float grain = sin(p.x * 11.3 + p.y * 2.7) * sin(p.z * 13.7 - p.y * 7.1);
    float stain = sin(p.x * 0.63 + p.z * 0.28) * sin(p.y * 0.83 + p.z * 0.46);
    vec3 color = stone_color.rgb * (0.91 + grain * 0.045 + stain * 0.085);
    ALBEDO = mix(color, color * 0.54, mortar * 0.68);
    ROUGHNESS = 0.94;
}
