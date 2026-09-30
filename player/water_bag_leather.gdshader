shader_type spatial;
uniform float fill_level : hint_range(0.0, 1.0) = 0.0;
varying vec3 skin_point;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	skin_point = VERTEX;
}

void fragment() {
	vec2 surface_point = skin_point.xy;
	float wear = noise(surface_point * 28.0);
	float grain = noise(surface_point * 720.0);
	float fold = pow(abs(sin(skin_point.x * 48.0 + skin_point.y * 17.0 + sin(skin_point.y * 24.0) * 0.45)), 16.0);
	float creases = (1.0 - fill_level) * fold;
	ALBEDO = vec3(0.27, 0.125, 0.055) * (0.84 + 0.25 * wear + (grain - 0.5) * 0.08) * (1.0 - creases * 0.15);
	ROUGHNESS = 0.84 + grain * 0.10;
	SPECULAR = 0.22;
	float gx = noise((surface_point + vec2(0.0006, 0.0)) * 720.0) - grain;
	float gy = noise((surface_point + vec2(0.0, 0.0006)) * 720.0) - grain;
	NORMAL_MAP = vec3(0.5 + gx * 0.11, 0.5 + gy * 0.11, 1.0);
}
