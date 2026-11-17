extends RefCounted
## Narrow capability: the consignment mission's actual rear passenger seat only.
static func allowed(actor: CharacterBody3D) -> bool:
 if not actor.get_meta("consignment_rear_combat",false) or actor.get_meta("cart_role","")!="passenger":return false
 var mount: Node=(actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
 return is_instance_valid(mount) and "cart" in mount and mount.cart.get_meta("consignment_cart",false) and mount.role=="passenger" and mount.seat_name=="ConsignmentRearSeat" and mount.transition.is_empty()

static func camera_exclusions(actor:CharacterBody3D) -> Array[RID]:
 var result:Array[RID]=[actor.get_rid()]
 if allowed(actor):
  for rid in actor.get_meta("consignment_camera_exclusions",[]):
   if typeof(rid)==TYPE_RID:result.append(rid)
 return result

static func fire_ready(actor:CharacterBody3D) -> bool:
 if not allowed(actor):return false
 var mount:Node=actor.get_meta("mounted_vehicle")
 var cover:Node=mount.cart.get_node_or_null("RebelCoveredWagon")
 return is_instance_valid(cover) and cover.openness>.90 and float(actor.get_meta("consignment_conceal_blend",0.0))<.001 and mount.cart.seat_sockets.ConsignmentRearSeat.position.z>3.59

static func aim_camera(actor:CharacterBody3D,fallback:Camera3D) -> Camera3D:
 var camera=actor.get_meta("consignment_fpv_camera") if actor.has_meta("consignment_fpv_camera") else null
 return camera if is_instance_valid(camera) and camera is Camera3D and allowed(actor) else fallback
static func aim_direction(actor:CharacterBody3D,fallback:Camera3D) -> Vector3:
 var camera:=aim_camera(actor,fallback)
 if not actor.has_meta("consignment_fpv_camera") or camera!=actor.get_meta("consignment_fpv_camera"):return -camera.global_basis.z
 return camera.project_ray_normal(Vector2(actor.get_meta("consignment_aim_uv",Vector2(.5,.5)))*camera.get_viewport().get_visible_rect().size)
