shader_type sky;
uniform vec3 sky_top_color : source_color = vec3(0.24, 0.36, 0.43);
uniform vec3 sky_horizon_color : source_color = vec3(0.66, 0.7, 0.67);
uniform vec3 ground_bottom_color : source_color = vec3(0.19, 0.22, 0.16);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform float night_visibility = 0.0;
uniform float sun_visibility = 1.0;
float hash(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
void sky() {
 vec3 direction = normalize(EYEDIR);
 float altitude = direction.y;
 vec3 color = mix(sky_horizon_color, sky_top_color, pow(max(altitude, 0.0), 0.19));
 if (altitude < 0.0) {
  color = mix(sky_horizon_color, ground_bottom_color, pow(-altitude, 0.3));
 }
 float above_horizon = smoothstep(0.015, 0.15, altitude);
 // A sparse fixed spherical field: stable in world space while the camera moves.
 vec3 grid = direction * 420.0;
 vec3 cell = floor(grid);
 float random_value = hash(cell);
 vec3 offset = vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 13.3));
 float star = 1.0 - smoothstep(0.045, 0.15, length(fract(grid) - offset));
 star *= step(0.985, random_value) * (0.3 + hash(cell + 22.0) * 0.7);
 color += vec3(0.75, 0.82, 1.0) * star * night_visibility * above_horizon;
 float moon_angle = acos(clamp(dot(direction, normalize(moon_direction)), -1.0, 1.0));
 float disc = 1.0 - smoothstep(0.0082, 0.0088, moon_angle);
 // Subtle mottling gives the moon a surface instead of a flat light spot.
 float mottling = sin(direction.x * 1700.0) * sin(direction.z * 1300.0);
 vec3 moon_color = vec3(0.88, 0.87, 0.78) * (0.85 + 0.1 * mottling);
 float halo = exp(-moon_angle * 100.0) * 0.045;
 color += vec3(0.6, 0.7, 0.9) * halo * night_visibility * above_horizon;
 color = mix(color, moon_color, disc * night_visibility * above_horizon);
 float sun_angle = acos(clamp(dot(direction, normalize(sun_direction)), -1.0, 1.0));
 color += vec3(1.0, 0.85, 0.6) * (1.0 - smoothstep(0.008, 0.01, sun_angle)) * sun_visibility * 2.0;
 COLOR = color;
}
