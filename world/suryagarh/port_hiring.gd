extends RefCounted
## One casual freight labour slot. Wages belong to the resident, not the player.
const SHIFT_MINUTES := 20.0
const WAGE := 1
var worker := ""
var ends_at := 0.0
var paid_day: Dictionary = {}
var earnings: Dictionary = {}
var delivery_key := ""
var claimed_deliveries: Dictionary = {}

func settle(now: float) -> void:
	if worker.is_empty() or not delivery_key.is_empty() or now < ends_at:
		return
	pay_worker(floori(ends_at / 1440.0))

func pay_worker(day: int) -> void:
	paid_day[worker] = day
	earnings[worker] = int(earnings.get(worker, 0)) + WAGE
	cancel()

func cancel() -> void:
	worker = ""
	ends_at = 0.0
	delivery_key = ""

func offer(identity: String, now: float) -> bool:
	settle(now)
	var day := floori(now / 1440.0)
	var minute := fposmod(now, 1440.0)
	if identity.is_empty() or not worker.is_empty() or minute < 7.0 * 60.0 or minute + SHIFT_MINUTES > 17.0 * 60.0:
		return false
	if int(paid_day.get(identity, -1)) >= day:
		return false
	worker = identity
	ends_at = now + SHIFT_MINUTES
	return true

func reserve_delivery(identity: String, receipt_key: String) -> bool:
	if identity.is_empty() or worker != identity or receipt_key.is_empty():
		return false
	if not delivery_key.is_empty() or claimed_deliveries.has(receipt_key):
		return false
	delivery_key = receipt_key
	return true

func complete_delivery(identity: String, receipt_key: String) -> bool:
	if worker.is_empty() or worker != identity or delivery_key.is_empty() or delivery_key != receipt_key:
		return false
	if claimed_deliveries.has(receipt_key):
		return false
	claimed_deliveries[receipt_key] = true
	pay_worker(floori(ends_at / 1440.0))
	return true

func export_state() -> Dictionary:
	return {"worker": worker, "ends_at": ends_at, "paid_day": paid_day.duplicate(), "earnings": earnings.duplicate(), "delivery_key": delivery_key, "claimed_deliveries": claimed_deliveries.duplicate()}

func restore_state(state: Dictionary) -> void:
	worker = str(state.get("worker", ""))
	ends_at = float(state.get("ends_at", 0.0))
	paid_day = state.get("paid_day", {}).duplicate() if state.get("paid_day") is Dictionary else {}
	earnings = state.get("earnings", {}).duplicate() if state.get("earnings") is Dictionary else {}
	delivery_key = str(state.get("delivery_key", "")) if not worker.is_empty() else ""
	claimed_deliveries = state.get("claimed_deliveries", {}).duplicate() if state.get("claimed_deliveries") is Dictionary else {}
