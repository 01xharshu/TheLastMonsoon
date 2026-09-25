extends RefCounted
## Shared height profile for the fort mesh and the Suryagarh terrain reservation.
static func height_at(x: float, z: float) -> float:
	var progress: float = clampf((50.0 - z) / 100.0, 0.0, 1.0)
	var climb: float = 1.15 * smoothstep(0.12, 0.3, progress) + 2.0 * smoothstep(0.33, 0.57, progress) + 2.4 * smoothstep(0.62, 0.82, progress) + 2.5 * smoothstep(0.84, 1.0, progress)
	var irregular: float = 0.24 * sin(x * 0.19 + z * 0.08) + 0.17 * sin(x * 0.37 - z * 0.23)
	var ridge: float = 0.85 * smoothstep(28.0, 50.0, absf(x))
	var hollow: float = -0.55 * exp(-pow((x - 18.0) / 9.0, 2.0) - pow((z - 3.0) / 11.0, 2.0))
	return climb + irregular + ridge + hollow
