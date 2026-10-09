extends Node3D
## Populated fictional gathering places and a consent-based family practice yard.
const Builder=preload("res://world/suryagarh/settlements/settlement_builder.gd")
const Actor=preload("res://characters/npcs/households/household_npc_actor.gd")
var b=Builder.new()
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var farm: Node3D
var college: Node3D
var courtyard: Node3D
var members: Array[Node3D]=[]
var residents: Array[Node3D]=[]
var pending: Array[Dictionary]=[]
var wait:=0.0
func _ready() -> void:
 name="StoryCommunity"
 b.wood=b.material(Color(.27,.17,.09));b.plaster=b.material(Color(.73,.67,.53));b.stone=b.material(Color(.42,.35,.25));b.tile=b.material(Color(.43,.24,.14))
 farm=site("ChachaFarm",Vector2(-360,338),Vector2(9,7),"Chacha · Farm practice")
 pavilion(farm,Vector2(9,7),false)
 college=site("CollegeReadingRoom",Vector2(-276,-469),Vector2(13,9),"College · Reading room")
 pavilion(college,Vector2(13,9),true)
 courtyard=site("RefreshmentCourtyard",Vector2(-278,-433),Vector2(10,8),"Refreshment courtyard · Conversations")
 pavilion(courtyard,Vector2(10,8),false)
 for i in 3:
  var member=preload("res://story/training_member.gd").new();member.name="PracticeMember%d"%i
  member.add_child(preload("res://characters/npcs/households/merchant.glb").instantiate());farm.add_child(member)
  member.position=Vector3(-3+i*3,0,-1);members.append(member)
 for site_node in [college,courtyard]:
  for i in 8:
   var table_x: float=-4 if i%4<2 else 1.2
   var at:=Vector3(table_x+(-1.05 if i%2==0 else 1.05),0,-2 if i<4 else 2)
   pending.append({"parent":site_node,"at":at,"index":i,"talk":true,"seated":i<4})
   if i<4:
    b.piece(site_node,"DiscussionSeat",at+Vector3(0,.40,0),Vector3(.7,.1,.7),b.wood)
    for dx in [-.28,.28]:b.piece(site_node,"SeatLeg",at+Vector3(dx,.18,0),Vector3(.10,.36,.6),b.wood)
  var talk=preload("res://story/community_conversation.gd").new();site_node.add_child(talk);talk.position=Vector3(2.25,.9,3.2)
  talk.lines.assign(["Reader: We compare accounts here. An official's answer is not always the whole truth.","Reader: Bring what you learn about Dev. We will listen, but we must be careful."] if site_node==college else ["Patron: Sit with us. News travels with the merchants and the people returning from the cantonment.","Patron: If you are searching for someone, listen before you speak. People are afraid of the officials."])
 # Add social groups at the station exterior and village spine, clear of gates.
 for point in [Vector2(310,157),Vector2(333,151),Vector2(-396,232),Vector2(-365,244)]:
  for i in 3:pending.append({"parent":self,"world":point+Vector2(i*1.3,0),"index":i,"talk":false})
func site(label: String,point: Vector2,half: Vector2,map_label: String) -> Node3D:
 var node:=Node3D.new();node.name=label;add_child(node)
 var highest: float=layout.height(point.x,point.y)
 for x in [-half.x,half.x]:
  for z in [-half.y,half.y]:highest=maxf(highest,layout.height(point.x+x,point.y+z))
 node.position=Vector3(point.x,highest+.22,point.y);node.set_meta("parking_label",map_label)
 b.piece(node,"EarthPlatform",Vector3(0,-.18,0),Vector3(half.x*2,.36,half.y*2),b.stone)
 # Walkable ramp to sampled ground at the south edge, without jump-only access.
 var start:=Vector3(0,-.03,half.y);var finish:=Vector3(0,layout.height(point.x,point.y+half.y+5)-node.position.y,half.y+5)
 var ramp:=b.piece(node,"AccessRamp",(start+finish)*.5,Vector3(3,.20,start.distance_to(finish)),b.stone)
 ramp.rotation.x=-atan2(finish.y-start.y,finish.z-start.z)
 return node
func pavilion(node: Node3D,half: Vector2,enclosed: bool) -> void:
 var back: float=-half.y+1
 b.piece(node,"BackWall",Vector3(0,1.6,back),Vector3(half.x*2,3.2,.24),b.plaster)
 if enclosed:
  for x in [-half.x,half.x]:b.piece(node,"SideWall",Vector3(x,1.6,0),Vector3(.24,3.2,half.y*2),b.plaster)
  for x in [-half.x*.65,half.x*.65]:b.piece(node,"FrontWall",Vector3(x,1.6,half.y),Vector3(half.x*.7,3.2,.24),b.plaster)
 for x in [-half.x+1,half.x-1]:
  for z in [back,half.y-1]:b.piece(node,"TimberPost",Vector3(x,1.55,z),Vector3(.18,3.1,.18),b.wood)
 for side in [-1,1]:
  var roof:=b.piece(node,"TileRoof",Vector3(side*half.x*.5,3.5,0),Vector3(half.x+1,.18,half.y*2+1),b.tile,false);roof.rotation.z=-side*.10
 b.piece(node,"Ridge",Vector3(0,3.55,0),Vector3(.3,.22,half.y*2+1),b.tile,false)
 if node==farm:
  for x in [-5,5]:b.piece(node,"PracticeRail",Vector3(x,.8,-4),Vector3(.12,1.6,.12),b.wood)
  return
 for x in [-4,1.2]:
  for z in [-2,2]:
   b.piece(node,"LowTable",Vector3(x,.65,z),Vector3(1.5,.12,1),b.wood)
   for dx in [-.6,.6]:b.piece(node,"TableLeg",Vector3(x+dx,.3,z),Vector3(.10,.6,.8),b.wood)
   for dx in [-1.2,1.2]:
    var cup:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.055;shape.bottom_radius=.04;shape.height=.10
    cup.mesh=shape;cup.material_override=b.stone;node.add_child(cup);cup.position=Vector3(x+dx*.25,.76,z)
 if enclosed:
  for x in [-7,7]:
   for y in [.65,1.25,1.85]:b.piece(node,"ReadingShelf",Vector3(x,y,back+.5),Vector3(3,.1,.7),b.wood)
  for i in 16:b.piece(node,"PaperBundle",Vector3(-8.3+float(i%8)*.36,.76+float(i/8)*.6,back+.5),Vector3(.28,.10,.4),b.plaster,false)
func _process(delta: float) -> void:
 wait-=delta
 if pending.is_empty() or wait>0:return
 wait=.15;var record: Dictionary=pending.pop_front()
 var actor=Actor.new();actor.name="CommunityResident%d"%residents.size();actor.movement_enabled=false;actor.cycle_offset=residents.size()*.43
 var variant:=1+residents.size()%4
 var sex: String="female" if (record.parent==courtyard and record.index%2==1) or (record.has("world") and record.index==1) else "male"
 actor.movement_profile=&"female" if sex=="female" else &"male"
 actor.add_child(load("res://characters/npcs/street_residents/%s_%02d.glb"%[sex,variant]).instantiate())
 record.parent.add_child(actor)
 if record.has("world"):
  var p: Vector2=record.world;actor.global_position=Vector3(p.x,layout.height(p.x,p.y),p.y)
 else:actor.position=record.at
 actor.rotation.y=PI*.5 if record.index%2==0 else -PI*.5
 for mesh in actor.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=130;mesh.visibility_range_end_margin=15
 var social=preload("res://story/community_social.gd").new();actor.add_child(social);social.person=actor;social.offset=residents.size()*.73;social.seated=record.get("seated",false);social.ground_y=actor.global_position.y
 residents.append(actor)
func _exit_tree() -> void:b.free()
