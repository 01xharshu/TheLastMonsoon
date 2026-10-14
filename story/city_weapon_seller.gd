extends Node3D
## Discoverable cart merchant; currency and goods use the ordinary saved inventory.
const Startup=preload("res://systems/world_startup.gd")
const Actions=preload("res://systems/action_permissions.gd")
const STOCK=[
 {"id":"enfield","name":"Enfield rifle","price":100,"quantity":1,"unique":true},
 {"id":"pistol","name":"Adams pistol","price":140,"quantity":1,"unique":true},
 {"id":"double_gun","name":"Double-barrel gun","price":120,"quantity":1,"unique":true},
 {"id":"utility_knife","name":"Knife","price":15,"quantity":1,"unique":true},
 {"id":"paper_cartridges","name":"12 paper cartridges","price":12,"quantity":12,"unique":false},
 {"id":"pistol_ball","name":"12 pistol balls","price":12,"quantity":12,"unique":false},
 {"id":"shot_charge","name":"8 shot charges","price":10,"quantity":8,"unique":false}]
var player: CharacterBody3D
var discovered=false
var configured=false
var pending_state: Dictionary={}
var cart: Node3D
var seller: Node3D
var panel: PanelContainer
var balance: Label
var buttons: Array[Button]=[]
var lease=-1
var prior_mouse=Input.MOUSE_MODE_CAPTURED
var service: Node
func _ready() -> void:
 name="CityWeaponSeller";call_deferred("configure")
func configure() -> void:
 player=get_parent().get_node("Player")
 global_position=Vector3(-395,get_parent().layout.height(-395,-290)+.08,-290)
 cart=preload("res://vehicles/horse_cart_candidate.gd").new();cart.variant=1;cart.name="WeaponSalesCart";cart.set_meta("booking_status","merchant_stock");add_child(cart)
 cart.boarding.set_physics_process(false)
 seller=preload("res://characters/npcs/households/household_npc_actor.gd").new();seller.name="WeaponSeller";seller.movement_enabled=false
 seller.set_meta("population_expansion_exempt",true);seller.set_meta("combat_faction","indian");seller.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/households/merchant.glb"));add_child(seller);seller.position=Vector3(2,0,2)
 for i in 3:
  var gun=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();cart.add_child(gun);gun.position=Vector3(-.4+i*.4,1.55,2.5);gun.rotation.z=PI/2
 var prompt=preload("res://story/rebellion_prompt.gd").new();prompt.director=self;prompt.action_id="shop";prompt.interaction_text="Browse weapons and ammunition";prompt.interaction_icon="weapon";add_child(prompt);prompt.position=Vector3(2,.9,1)
 var collision=CollisionShape3D.new();var shape=SphereShape3D.new();shape.radius=.35;collision.shape=shape;prompt.add_child(collision)
 service=Actions.install(player)
 var layer=CanvasLayer.new();layer.layer=90;add_child(layer)
 var backdrop=Control.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(backdrop);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel=PanelContainer.new();backdrop.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-260;panel.offset_right=260;panel.offset_top=-260;panel.offset_bottom=260
 var margin=MarginContainer.new();panel.add_child(margin)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,20)
 var list=VBoxContainer.new();list.add_theme_constant_override("separation",10);margin.add_child(list)
 var title=Label.new();title.text="Weapons at the cart";title.add_theme_font_size_override("font_size",25);list.add_child(title)
 balance=Label.new();list.add_child(balance)
 for i in STOCK.size():
  var button=Button.new();button.text="%s · %d rupees"%[STOCK[i].name,STOCK[i].price];button.pressed.connect(buy.bind(i));list.add_child(button);buttons.append(button)
 var close=Button.new();close.text="Close · Escape";close.pressed.connect(close_shop);list.add_child(close)
 panel.hide();configured=true;restore_state(pending_state);pending_state={}
 player.inventory.inventory_changed.connect(refresh)
func _process(_delta: float) -> void:
 if not configured:return
 if not discovered and player.global_position.distance_to(global_position)<18:
  discovered=true;set_meta("parking_label","Illegal weapon seller");player.get_node("UI/WorldMap").refresh_sites()
 if panel.visible and (player.health<=0 or player.global_position.distance_to(global_position)>8 or player.get_meta("story_cinematic",false)):close_shop()
func can_request(id: String) -> bool:
 return configured and id=="shop" and not panel.visible and player.health>0 and not player.get_meta("story_cinematic",false)
func request(id: String,actor: CharacterBody3D) -> bool:
 if actor!=player or not can_request(id) or actor.global_position.distance_to(global_position)>7:return false
 var domains: Array[StringName]=[&"move",&"attack",&"interact"]
 lease=service.acquire(self,domains)
 if lease<0:return false
 discovered=true;set_meta("parking_label","Illegal weapon seller");player.get_node("UI/WorldMap").refresh_sites()
 prior_mouse=Input.mouse_mode;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;player.set_meta("weapon_shop_open",true);panel.show();refresh();buttons[0].grab_focus();return true
func buy(index: int) -> bool:
 if not configured or not panel.visible or index<0 or index>=STOCK.size() or player.global_position.distance_to(global_position)>8:return false
 var item: Dictionary=STOCK[index];var inv: Node=player.inventory
 if item.unique and inv.has_item(item.id):return false
 if not inv.remove_item("rupees",item.price):return false
 if not inv.add_item(item.id,item.quantity):inv.add_item("rupees",item.price);return false
 inv.message_requested.emit("Bought %s · %d rupees"%[item.name,item.price]);refresh();return true
func refresh() -> void:
 if not configured:return
 balance.text="Carried money: %d rupees"%player.inventory.get_item_count("rupees")
 for i in STOCK.size():buttons[i].disabled=player.inventory.get_item_count("rupees")<int(STOCK[i].price) or (STOCK[i].unique and player.inventory.has_item(STOCK[i].id))
func close_shop() -> void:
 if not configured or not panel.visible:return
 panel.hide();player.set_meta("weapon_shop_open",false);service.release(lease);lease=-1;Input.mouse_mode=prior_mouse
func _input(event: InputEvent) -> void:
 if configured and panel.visible and event.is_action_pressed("ui_cancel"):close_shop();get_viewport().set_input_as_handled()
func export_state() -> Dictionary:return {"discovered":discovered} if configured else pending_state.duplicate(true)
func restore_state(data: Dictionary) -> void:
 if not configured:pending_state=data.duplicate(true);return
 close_shop()
 discovered=bool(data.get("discovered",false));set_meta("parking_label","Illegal weapon seller" if discovered else "")
 player.get_node("UI/WorldMap").refresh_sites()
func _exit_tree() -> void:
 close_shop()
