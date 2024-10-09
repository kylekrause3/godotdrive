extends RigidBody3D

@export var spring_strength : float = 100
@export var spring_damper : float = 15
@export var height_from_ground : float = 1

# todo: use lookup curve for dynamic traction with side-to-side velocity (more grip on less insane turns)
@export var front_tire_grip_pct : float = 0.7
@export var back_tire_grip_pct : float = 0.7

@export var speed : float = 50
@export var top_speed : float = 10 # units/sec
@export var engine_torque: Curve

@onready var WheelBL = $WheelBL
@onready var WheelBR = $WheelBR
@onready var WheelFL = $WheelFL
@onready var WheelFR = $WheelFR

var LineDrawer = preload("res://DrawLine3D.gd").new()

var maxTurnDegrees = 30

var forces = []
var force_positions = []

var accel_force : Vector3
var sideways_force : Vector3
var susp_force : Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(LineDrawer)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# force for each tire
	handle_wheel_force(WheelBR, back_tire_grip_pct, true, delta)
	handle_wheel_force(WheelBL, back_tire_grip_pct, true, delta)
	handle_wheel_force(WheelFR, front_tire_grip_pct, false, delta)
	handle_wheel_force(WheelFL, front_tire_grip_pct, false, delta)
	
	var steering = Input.get_axis("left", "right")
	WheelFL.rotation_degrees.y = maxTurnDegrees * -steering
	WheelFR.rotation_degrees.y = maxTurnDegrees * -steering


func _integrate_forces(state):
	for i in len(forces):
		apply_force(forces[i], force_positions[i])
	forces.clear()
	force_positions.clear()

func handle_wheel_force(wheel : Node3D, grip_amount : float, drive_wheel : bool, delta : float) -> void:
	var car_up = self.global_transform.basis.y
	var car_left = self.global_transform.basis.x
	var car_forward = self.global_transform.basis.z
	LineDrawer.DrawLine((self.global_position + car_up), (self.global_position + car_up) + car_up, Color(0, 1, 0))
	LineDrawer.DrawLine((self.global_position + car_up), (self.global_position + car_up) + car_left, Color(1, 0, 0))
	LineDrawer.DrawLine((self.global_position + car_up), (self.global_position + car_up) + car_forward, Color(0, 0, 1))
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(wheel.global_position, wheel.global_position - (car_up * (height_from_ground + 1)))
	var collision = space.intersect_ray(query)
	var wheelpointvelocity : Vector3 = get_point_velocity(wheel.position)
	if collision:
		var collisionlength = (wheel.global_position - collision.position).length()
		var offset : float = height_from_ground - collisionlength
		
		# velocity along spring direction
		var springwardvelocity : float = car_up.dot(wheelpointvelocity)
		var suspensionacceleration : float = ((offset - 0.08) * spring_strength) - (springwardvelocity * spring_damper)
		suspensionacceleration = clamp(suspensionacceleration, 0, mass * gravity_scale * 9.8)
		susp_force = suspensionacceleration * car_up
		apply_force(susp_force, wheel.position)
		LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (susp_force /100), Color(0, 1, 0, 1))
		
		var wheel_right = (-car_left).rotated(Vector3(0, 1, 0), wheel.rotation.y)
		var rightwardvelocity = wheel_right.dot(wheelpointvelocity)
		print(str(wheelpointvelocity))
		# we want to be pushed in the opposite direction as how much velocity is perpendicular to our wheels
		var sidewaysacceleration = ((-rightwardvelocity) * grip_amount)
		sideways_force = sidewaysacceleration * wheel_right
		apply_force(sideways_force, Vector3(wheel.position.x, 0, wheel.position.z))
		LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (sideways_force /100), Color(1, 0, 0))
		
		var throttle = Input.get_axis("backward", "forward")
		accel_force = Vector3.ZERO
		if(throttle != 0.0 && drive_wheel):
			var currentspeed = car_forward.dot(self.linear_velocity)
			currentspeed = clamp(abs(currentspeed), 0, top_speed)
			var applied_torque = engine_torque.sample(currentspeed / top_speed) * throttle * speed
			accel_force = applied_torque * car_forward
			apply_central_force(accel_force) # shouldn't be central but debugging
			LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (accel_force /100), Color(0, 0, 1))
		var total_force = susp_force + sideways_force + accel_force
		#forces.push_back(total_force)
		#force_positions.push_back(wheel.position)
		# apply_force(total_force, wheel.position)
			# LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (car_left * applied_torque), Color(1, 1, 0))

# https://www.reddit.com/r/godot/comments/eg9mdc/comment/fhf5la8
func get_point_velocity(local_point :Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(local_point - center_of_mass)
