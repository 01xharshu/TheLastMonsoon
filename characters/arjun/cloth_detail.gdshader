shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D base_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_atlas = false;
uniform vec4 cloth_color : source_color = vec4(0.035, 0.04, 0.05, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform int garment_kind = 0;
uniform vec2 fabric_sway = vec2(0.0);
uniform float rest_fold : hint_range(0.0, 1.0) = 0.0;
varying vec3 cloth_position;
void vertex() {
 cloth_position = VERTEX;
 if (garment_kind == 1) {
  // The split hem gathers at the waist when the thighs fold toward the torso.
  // Keep the cloth attached while clearing the trouser front in seated poses.
  float lower_hem = 1.0 - smoothstep(0.72, 1.015, VERTEX.y);
  VERTEX.y += rest_fold * lower_hem * 0.20;
  VERTEX.xz *= 1.0 - rest_fold * lower_hem * 0.20;
 }
 float loose = garment_kind == 1 ? 1.0 - smoothstep(0.72, 1.015, VERTEX.y) : (garment_kind == 2 ? 1.0 - smoothstep(0.60, 1.025, VERTEX.y) : 0.0);
 loose *= loose;
 VERTEX.xz += fabric_sway * loose;
}
float grain(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
void fragment() {
 vec3 base = has_atlas ? texture(base_atlas, UV).rgb * cloth_color.rgb : cloth_color.rgb;
 // Millimetre-scale warp/weft, filtered before it becomes distant moire.
 vec2 p = vec2(cloth_position.x + cloth_position.z * 0.37, cloth_position.y);
 vec2 frequency = p * 850.0;
 float fade = 1.0 - smoothstep(0.15, 0.6, max(length(dFdx(frequency)), length(dFdy(frequency))));
 float warp = sin(frequency.x * 6.283185);
 float weft = sin(frequency.y * 6.283185);
 float yarn = (warp * 0.5 + weft * 0.5) * fade;
 float mottling = sin(p.x * 35.0 + sin(p.y * 21.0)) * sin(p.y * 28.0) * 0.022;
 ALBEDO = base * (1.0 + mottling + yarn * 0.035) * mix(1.0, 0.68, wetness);
 ROUGHNESS = clamp(0.88 + yarn * 0.025 - wetness * 0.16, 0.65, 0.95);
 SPECULAR = 0.22;
 // Perturb the existing geometric normal; seams/folds remain actual geometry.
 vec3 dpdx = dFdx(VERTEX);
 vec3 dpdy = dFdy(VERTEX);
 float height = yarn * 0.00012;
 vec3 rx = cross(dpdy, NORMAL);
 vec3 ry = cross(NORMAL, dpdx);
 float determinant = dot(dpdx, rx);
 vec3 gradient = (dFdx(height) * rx + dFdy(height) * ry) / max(abs(determinant), 0.000001) * sign(determinant);
 NORMAL = normalize(NORMAL - gradient);
}
