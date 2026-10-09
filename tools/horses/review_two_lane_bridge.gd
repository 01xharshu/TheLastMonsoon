extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size = Vector2i(1280,720)
 var world := Node3D.new()
 root.add_child(world)
 var bridge: Node3D = load("res://world/suryagarh/timber_bridge.gd").new()
 world.add_child(bridge)
 var boat: CharacterBody3D = load("res://vehicles/river_boat.gd").new()
 world.add_child(boat)
 boat.set_physics_process(false)
 boat.global_position = bridge.global_position+Vector3(0,.03,-2)
 var water := MeshInstance3D.new()
 var surface := PlaneMesh.new()
 surface.size = Vector2(80,80)
 water.mesh = surface
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(.15,.28,.3)
 material.roughness = .32
 water.material_override = material
 water.position = bridge.global_position
 world.add_child(water)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-35,-30,0)
 world.add_child(sun)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(.55,.68,.77)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color(.7,.75,.8)
 env.environment.ambient_light_energy = .7
 world.add_child(env)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.position = bridge.global_position+Vector3(24,17,28)
 camera.look_at(bridge.global_position+Vector3(0,bridge.deck_height*.6,0))
 camera.current = true
 for direction in [-1.0,1.0]:
  var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
  world.add_child(cart)
  cart.global_position = bridge.global_position+Vector3(0,bridge.deck_height,direction*bridge.LANE_OFFSET)
  cart.rotation.y = -direction*PI*.5
  cart.set_physics_process(false)
 for i in 10: await process_frame
 RenderingServer.force_draw(false)
 var file := OS.get_environment("TLM_BRIDGE_REVIEW")
 if not file.is_empty(): root.get_texture().get_image().save_png(file)
 print("TWO LANE BRIDGE RENDER COMPLETE")
 quit()
