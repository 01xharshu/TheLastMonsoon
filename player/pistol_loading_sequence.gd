extends RefCounted
## Per-charge contact and pacing shared by combat and the visual solver.
const PREPARE_SECONDS := 0.6
const CHARGE_SECONDS := 3.0
const FINISH_SECONDS := 0.4

static func duration(charges: int) -> float:
	return PREPARE_SECONDS + max(1,charges)*CHARGE_SECONDS + FINISH_SECONDS

static func state(progress: float, charges: int) -> Dictionary:
	var elapsed := clampf(progress,0.0,1.0)*duration(charges)
	var loading_time := elapsed-PREPARE_SECONDS
	var cycle := clampi(int(floor(maxf(0.0,loading_time)/CHARGE_SECONDS)),0,maxi(1,charges)-1)
	var phase := clampf((loading_time-cycle*CHARGE_SECONDS)/CHARGE_SECONDS,0.0,1.0)
	var reach := smoothstep(0.10,0.40,phase)*(1.0-smoothstep(0.78,0.98,phase))
	return {"reach":reach,"charge_visible":loading_time >= 0.0 and phase >= 0.08 and phase < 0.55,
		"inserted":clampi(int(floor((loading_time-CHARGE_SECONDS*0.55)/CHARGE_SECONDS))+1,0,charges)}
