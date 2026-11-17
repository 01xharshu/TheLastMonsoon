extends Node3D
## A saved deposit account, denominated in hundredths of a rupee.
const Actions = preload("res://systems/action_permissions.gd")
const DAILY_RATE_BASIS_POINTS := 5
const MAX_BALANCE_PAISE := 100000000000
var balance_paise := 0
var last_day := -1
var interest_remainder := 0
var interest_earned_paise := 0
var player: CharacterBody3D
var clock: Node
var teller: Node3D
var prompt: Interactable
var panel: PanelContainer
var balance_label: Label
var amount: SpinBox
var permissions: Node
var lease := -1
var prior_mouse := Input.MOUSE_MODE_CAPTURED
var pending_state: Dictionary = {}
var configured := false
var encounters: Node
var customers: Array[Dictionary] = []

func _ready() -> void:
 name = "BankService"
 call_deferred("configure")

func configure() -> void:
 var world := get_parent()
 var treasury := world.get_node("Settlement/AdministrativeDistrict/DistrictTreasury")
 player = world.get_node("Player")
 clock = world.get_node("GameTimeSystem")
 teller = preload("res://characters/npcs/households/household_npc_actor.gd").new()
 teller.name = "BankTeller"
 teller.movement_enabled = false
 teller.set_meta("population_expansion_exempt", true)
 teller.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/households/merchant.glb"))
 treasury.add_child(teller)
 teller.position = Vector3(6, .24, 1.6)
 var sign := Label3D.new()
 sign.text = "BANK"
 sign.font_size = 48
 sign.pixel_size = .006
 sign.position = Vector3(6, 2.35, 1.0)
 treasury.add_child(sign)
 encounters = world.get_node("CombatEncounters")
 for index in 2:
  var customer := preload("res://characters/npcs/indian/indian_street_actor.gd").new()
  customer.name = "BankCustomer%d" % index
  customer.movement_enabled = false
  customer.set_meta("population_expansion_exempt", true)
  customer.set_meta("social_role", "bank_customer")
  customer.set_meta("daily_activity", "visiting_bank")
  customer.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/workman_%02d.glb" % (index + 1), false))
  treasury.add_child(customer)
  customer.position = Vector3(1.0 + index * 2.0, .24, 7.0)
  encounters.ground_exclusions.append(customer.body_collider.get_rid())
  for mesh: GeometryInstance3D in customer.find_children("*", "GeometryInstance3D", true, false):
   mesh.visibility_range_end = 150
  customers.append({"actor": customer, "points": [treasury.to_global(customer.position), treasury.to_global(Vector3(1.0 + index * 2.0, .24, 3.8))], "index": 1, "pause": float(index) * 5.0, "elapsed": 0.0, "wallet": 20 + index * 5, "account": 0})
 prompt = preload("res://story/rebellion_prompt.gd").new()
 prompt.director = self
 prompt.action_id = "bank"
 prompt.interaction_text = "Speak to the bank clerk"
 prompt.interaction_icon = "hand"
 treasury.add_child(prompt)
 prompt.position = Vector3(6, .9, 3.0)
 var collision := CollisionShape3D.new()
 var sphere := SphereShape3D.new()
 sphere.radius = .35
 collision.shape = sphere
 prompt.add_child(collision)
 permissions = Actions.install(player)
 var layer := CanvasLayer.new()
 layer.layer = 90
 add_child(layer)
 panel = PanelContainer.new()
 layer.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left = -250
 panel.offset_right = 250
 panel.offset_top = -180
 panel.offset_bottom = 180
 var margin := MarginContainer.new()
 panel.add_child(margin)
 for edge in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + edge, 20)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 margin.add_child(column)
 var title := Label.new()
 title.text = "District Bank"
 title.add_theme_font_size_override("font_size", 25)
 column.add_child(title)
 balance_label = Label.new()
 column.add_child(balance_label)
 var rate := Label.new()
 rate.text = "Interest: 0.05% per game day"
 column.add_child(rate)
 amount = SpinBox.new()
 amount.min_value = 1
 amount.max_value = 1000000
 amount.step = 1
 amount.value = 1
 amount.prefix = "Rupees "
 column.add_child(amount)
 for entry in [["Deposit", deposit], ["Withdraw", withdraw], ["Close · Escape", close_bank]]:
  var button := Button.new()
  button.text = entry[0]
  button.pressed.connect(entry[1])
  column.add_child(button)
 panel.hide()
 configured = true
 restore_state(pending_state)
 pending_state = {}
 player.inventory.inventory_changed.connect(refresh)

func current_day() -> int:
 return int(floor(maxf(0.0, float(clock.total_game_minutes)) / 1440.0))

func accrue() -> void:
 if not configured: return
 var day := current_day()
 if last_day < 0:
  last_day = day
  return
 if day <= last_day: return
 var days := day - last_day
 # Compound each day while retaining fractional paise across save/load.
 for unused in days:
  if balance_paise >= MAX_BALANCE_PAISE:
   break
  var numerator := balance_paise * DAILY_RATE_BASIS_POINTS + interest_remainder
  var credit := mini(MAX_BALANCE_PAISE - balance_paise, int(numerator / 10000))
  balance_paise += credit
  interest_earned_paise = mini(MAX_BALANCE_PAISE, interest_earned_paise + credit)
  interest_remainder = numerator % 10000
 last_day = day

func can_request(id: String) -> bool:
 return configured and id == "bank" and not panel.visible and player.health > 0 and is_instance_valid(teller) and not teller.get_meta("dead", false) and not teller.get_meta("knocked_out", false) and not player.get_meta("story_cinematic", false)

func request(id: String, actor: CharacterBody3D) -> bool:
 if actor != player or not can_request(id) or actor.global_position.distance_to(teller.global_position) > 4.0:
  return false
 var domains: Array[StringName] = [&"move", &"attack", &"interact"]
 lease = permissions.acquire(self, domains)
 if lease < 0: return false
 accrue()
 prior_mouse = Input.mouse_mode
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 panel.show()
 refresh()
 if DisplayServer.get_name() != "headless": amount.get_line_edit().grab_focus()
 return true

func transaction_available() -> bool:
 return configured and panel.visible and is_instance_valid(player) and player.health > 0 and is_instance_valid(teller) and not teller.get_meta("dead", false) and not teller.get_meta("knocked_out", false) and not player.get_meta("story_cinematic", false) and player.global_position.distance_to(teller.global_position) <= 5.0

func deposit() -> void:
 if not transaction_available(): return
 accrue()
 var rupees := int(amount.value)
 if balance_paise + rupees * 100 > MAX_BALANCE_PAISE or not player.inventory.remove_item("rupees", rupees):
  player.inventory.message_requested.emit("Unable to deposit that amount")
  return
 balance_paise += rupees * 100
 refresh()

func withdraw() -> void:
 if not transaction_available(): return
 accrue()
 var rupees := int(amount.value)
 if balance_paise < rupees * 100:
  player.inventory.message_requested.emit("Insufficient bank balance")
  return
 if player.inventory.add_item("rupees", rupees):
  balance_paise -= rupees * 100
 refresh()

func refresh() -> void:
 if not configured: return
 balance_label.text = "Bank balance: %d.%02d rupees    Carried: %d rupees\nInterest earned: %d.%02d rupees" % [int(balance_paise / 100), balance_paise % 100, player.inventory.get_item_count("rupees"), int(interest_earned_paise / 100), interest_earned_paise % 100]

func close_bank() -> void:
 if not configured or not panel.visible: return
 panel.hide()
 permissions.release(lease)
 lease = -1
 Input.mouse_mode = prior_mouse

func _physics_process(delta: float) -> void:
 if not configured: return
 for customer in customers:
  var actor: Node3D = customer.actor
  if not is_instance_valid(actor) or actor.get_meta("dead", false) or actor.get_meta("knocked_out", false): continue
  customer.elapsed += delta
  if customer.elapsed < preload("res://systems/simulation_budget.gd").interval(actor, player): continue
  var elapsed: float = customer.elapsed
  customer.elapsed = maxf(0.0, elapsed - .5)
  elapsed = minf(elapsed, .5)
  if customer.pause > 0.0:
   customer.pause = maxf(0.0, customer.pause - elapsed)
   actor.travel_speed = 0.0
   continue
  for slice in 5:
   if elapsed <= 0.0: break
   var step := minf(elapsed, .1)
   elapsed -= step
   if encounters.navigate_patrol(customer, customer.points[customer.index], 1.0, step):
    customer.index = 1 - customer.index
    actor.set_meta("daily_activity", "depositing_at_bank" if customer.index == 0 else "visiting_bank")
    if customer.index == 0:
     var paid := mini(int(customer.wallet), 2)
     if paid > 0:
      customer.wallet -= paid
      customer.account += paid
      customer["deposits"] = int(customer.get("deposits", 0)) + 1
    customer.pause = 8.0 if customer.index == 0 else 4.0
    break

func _process(_delta: float) -> void:
 if configured and panel.visible:
  if not transaction_available():
   close_bank()
  else:
   accrue()
   refresh()

func _input(event: InputEvent) -> void:
 if configured and panel.visible and event.is_action_pressed("ui_cancel"):
  close_bank()
  get_viewport().set_input_as_handled()

func export_state() -> Dictionary:
 if not configured: return pending_state.duplicate(true)
 accrue()
 var visitors := []
 for customer in customers:
  var actor: Node3D = customer.actor
  visitors.append({"position": [actor.position.x, actor.position.y, actor.position.z],
   "index": customer.index, "pause": customer.pause,
   "deposits": customer.get("deposits", 0), "wallet": customer.wallet, "account": customer.account})
 return {"balance_paise": balance_paise, "last_day": last_day,
  "interest_remainder": interest_remainder, "interest_earned_paise": interest_earned_paise, "visitors": visitors}

func restore_state(data: Dictionary) -> void:
 if not configured:
  pending_state = data.duplicate(true)
  return
 close_bank()
 balance_paise = clampi(int(data.get("balance_paise", 0)), 0, MAX_BALANCE_PAISE)
 interest_remainder = clampi(int(data.get("interest_remainder", 0)), 0, 9999)
 interest_earned_paise = clampi(int(data.get("interest_earned_paise", 0)), 0, MAX_BALANCE_PAISE)
 last_day = int(data.get("last_day", current_day()))
 var visitors: Array = data.get("visitors", [])
 for index in mini(visitors.size(), customers.size()):
  if not visitors[index] is Dictionary: continue
  var visitor: Dictionary = visitors[index]
  var location: Array = visitor.get("position", [])
  if location.size() == 3:
   var point := Vector3(float(location[0]), float(location[1]), float(location[2]))
   if point.is_finite() and point.x >= .5 and point.x <= 3.5 and point.z >= 3.5 and point.z <= 7.3 and absf(point.y - .24) < .3:
    customers[index].actor.position = point
  customers[index].index = clampi(int(visitor.get("index", 1)), 0, 1)
  customers[index].pause = clampf(float(visitor.get("pause", 0.0)), 0.0, 8.0)
  customers[index]["deposits"] = maxi(0, int(visitor.get("deposits", 0)))
  customers[index]["wallet"] = clampi(int(visitor.get("wallet", 20 + index * 5)), 0, 1000000)
  customers[index]["account"] = clampi(int(visitor.get("account", 0)), 0, 1000000)
 accrue()
 refresh()

func _exit_tree() -> void:
 close_bank()
