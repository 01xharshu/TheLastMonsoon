extends RefCounted
## Role contracts are separate from individual identity and saved activity state.
const CATALOGUE := {
	"tenant_farmer":{"class":"working","work":["hoe","sow"],"leisure":["social"]},
	"labourer":{"class":"working","work":["carry","sort"],"leisure":["social"]},
	"porter":{"class":"working","work":["carry","unload"],"leisure":["social"]},
	"household_worker":{"class":"working","work":["well","cook","carry"],"leisure":["social"]},
	"groom":{"class":"working","work":["groom","feed"],"leisure":["social"]},
	"landowner":{"class":"wealthy","work":["inspect","office"],"leisure":["social"]},
	"landowner_spouse":{"class":"wealthy","work":["household_visit"],"leisure":["social"]},
	"clerk":{"class":"respectable","work":["office","records"],"leisure":["social"]},
	"vendor":{"class":"working","work":["market","sort"],"leisure":["social"]},
	"hospital_attendant":{"class":"working","work":["hospital","carry"],"leisure":["social"]},
	"guard":{"class":"uniformed","work":["guard","patrol"],"leisure":["social"]},
	"villager":{"class":"working","work":[],"leisure":["social","travel"]}
}

static func permits(role:String,activity:String)->bool:
	if not CATALOGUE.has(role):return false
	return activity in CATALOGUE[role].work or activity in CATALOGUE[role].leisure

static func wealth(role:String)->String:
	return CATALOGUE.get(role,{"class":"working"}).get("class","working")
