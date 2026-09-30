extends RefCounted
## One shared gun-space path for the cartridge, ramrod and loading fingers.
const RELOAD_SECONDS := 12.0
const MOUTH := Vector3(1.04, 0.057, 0)
const ROD_CENTER := Vector3(0.56, -0.003, 0)
const ROD_HALF := 0.48
static func phase_ease(p: float, a: float, b: float) -> float:
	# Zero velocity and acceleration at both ends of each loading gesture.
	var t := clampf((p-a)/(b-a),0.0,1.0)
	return t*t*t*(t*(t*6.0-15.0)+10.0)

static func state(p: float) -> Dictionary:
	var rod := Transform3D.IDENTITY
	var contact := Vector3(0.20,-0.032,0)
	var curl := 0.90
	var cartridge := Transform3D.IDENTITY
	var cartridge_visible := p >= 0.10 and p < 0.34
	var depth := 0.0
	var hand_height := 0.30
	var turning := 0.0
	if p < 0.34:
		var insertion := phase_ease(p,0.26,0.34)
		# +Y is the paper tube axis: its lower end meets the muzzle first.
		var paper_basis := Basis(Vector3(0,0,-1),Vector3.RIGHT,Vector3(0,-1,0))
		var paper_center := Vector3(0.78,0.057,-0.12).lerp(MOUTH + Vector3(0.040-0.085*insertion,0,0),phase_ease(p,0.10,0.26))
		cartridge = Transform3D(paper_basis,paper_center)
		contact = paper_center + Vector3(0.026,0,0)
	elif p < 0.52:
		# Rod pauses during each open-finger regrip; closed pulls follow
		# one fixed material point rather than sliding through the fingers.
		var pulls := [[0.36,0.395,0.0,0.30,0.90,1.20,false],
			[0.395,0.42,0.30,0.30,1.20,0.90,true],
			[0.42,0.45,0.30,0.60,0.90,1.20,false],
			[0.45,0.48,0.60,0.60,1.20,0.85,true],
			[0.48,0.52,0.60,0.98,0.85,1.23,false]]
		var height := 0.90
		for pull in pulls:
			if p >= pull[0] and p < pull[1]:
				var fraction := phase_ease(p,pull[0],pull[1])
				rod.origin.x = lerpf(pull[2],pull[3],fraction)
				height = lerpf(pull[4],pull[5],fraction)
				curl = 0.95-0.83*sin(PI*fraction) if pull[6] else 0.95
		contact = (MOUTH+Vector3(-0.019,0,0)).lerp(Vector3(height,-0.003,0),phase_ease(p,0.34,0.36))
	elif p < 0.58:
		turning = phase_ease(p,0.52,0.58)
		var rotation := Basis(Vector3.FORWARD,PI*turning)
		var center := (ROD_CENTER+Vector3(0.98,0,0)).lerp(MOUTH+Vector3(ROD_HALF,0,0),turning)
		center.z -= sin(PI*turning)*0.40
		center.y -= sin(PI*turning)*0.20
		rod = Transform3D(rotation,center-rotation*ROD_CENTER)
		contact = rod * Vector3(lerpf(0.25,0.67,turning),-0.003,0)
		curl = 0.95-0.83*sin(PI*turning)
	elif p < 0.91:
		# Three short strokes, with the fingers opening to regrip between them.
		var strokes := [[0.58,0.63,0.0,0.30,0.37,0.07,false],
			[0.63,0.65,0.30,0.30,0.07,0.37,true],
			[0.65,0.70,0.30,0.60,0.37,0.07,false],
			[0.70,0.72,0.60,0.60,0.07,0.32,true],
			[0.72,0.76,0.60,0.85,0.32,0.07,false],
			[0.76,0.80,0.85,0.55,0.07,0.37,false],
			[0.80,0.82,0.55,0.55,0.37,0.07,true],
			[0.82,0.86,0.55,0.25,0.07,0.37,false],
			[0.86,0.88,0.25,0.25,0.37,0.07,true],
			[0.88,0.91,0.25,0.0,0.07,0.32,false]]
		for stroke in strokes:
			if p >= stroke[0] and p < stroke[1]:
				var fraction := phase_ease(p,stroke[0],stroke[1])
				depth = lerpf(stroke[2],stroke[3],fraction)
				hand_height = lerpf(stroke[4],stroke[5],fraction)
				curl = 0.95-0.83*sin(PI*fraction) if stroke[6] else 0.95
		var rotation := Basis(Vector3.FORWARD,PI)
		rod = Transform3D(rotation,MOUTH+Vector3(ROD_HALF-depth,0,0)-rotation*ROD_CENTER)
		contact = MOUTH+Vector3(hand_height,0,0)
	elif p < 0.96:
		turning = phase_ease(p,0.91,0.96)
		var rotation := Basis(Vector3.FORWARD,PI*(1.0-turning))
		var center := (MOUTH+Vector3(ROD_HALF,0,0)).lerp(ROD_CENTER+Vector3(0.98,0,0),turning)
		center.z -= sin(PI*turning)*0.40
		center.y -= sin(PI*turning)*0.20
		rod = Transform3D(rotation,center-rotation*ROD_CENTER)
		contact = rod * Vector3(lerpf(0.72,0.25,turning),-0.003,0)
		curl = 0.95
	else:
		rod.origin.x = 0.98*(1.0-phase_ease(p,0.96,1.0))
		contact = Vector3(1.23,-0.003,0).lerp(Vector3(0.90,-0.003,0),phase_ease(p,0.96,1.0))
		curl = 0.95
	return {"rod":rod,"contact":contact,"curl":curl,"cartridge":cartridge,"cartridge_visible":cartridge_visible,"depth":depth}
