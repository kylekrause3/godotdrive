extends RigidBody3D

@export var spring_strength : float = 100
@export var spring_damper : float = 35
@export var wheel_height : float = 0.25

# todo: use lookup curve for dynamic traction with side-to-side velocity (more grip on less insane turns)
@export var front_tire_grip_pct : float = 0.7
@export var back_tire_grip_pct : float = 0.7

@export var maxTurnDegrees = 30

@export var speed : float = 50
@export var top_speed : float = 10 # units/sec
@export var engine_torque: Curve
@export var reverse_torque : float = 0.8
@export var turning_radius: Curve

@onready var WheelBL = $CollisionShape3D.get_node("WheelBL")
@onready var WheelBR = $CollisionShape3D.get_node("WheelBR")
@onready var WheelFL = $CollisionShape3D.get_node("WheelFL")
@onready var WheelFR = $CollisionShape3D.get_node("WheelFR")

var LineDrawer = preload("res://DrawLine3D.gd").new()

var forces = []
var force_positions = []

var accel_force : Vector3
var sideways_force : Vector3
var susp_force : Vector3

@onready var tracked_max_turn_degrees : float = maxTurnDegrees

var tracked_wheel_rotation : float

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(LineDrawer)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# force for each tire
	handle_wheel_force(WheelBR, back_tire_grip_pct, true, delta)
	handle_wheel_force(WheelBL, back_tire_grip_pct, true, delta)
	handle_wheel_force(WheelFR, front_tire_grip_pct, false, delta)
	handle_wheel_force(WheelFL, front_tire_grip_pct, false, delta)
	
	var steering = Input.get_axis("left", "right")
	tracked_wheel_rotation = lerp(tracked_wheel_rotation, tracked_max_turn_degrees * -steering, 5 * delta)
	WheelFL.rotation_degrees.y = tracked_wheel_rotation
	WheelFR.rotation_degrees.y = tracked_wheel_rotation


func handle_wheel_force(wheel : Node3D, grip_amount : float, drive_wheel : bool, delta : float) -> void:
	var car_up = self.global_transform.basis.y
	var car_left = self.global_transform.basis.x
	var car_forward = self.global_transform.basis.z
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(wheel.global_position, wheel.global_position - (car_up * (wheel_height)))
	query.collision_mask = 0b00000000_00000000_00000000_00000001
	var collision = space.intersect_ray(query)
	if collision:
		var springDir : Vector3 = wheel.global_transform.basis.y;
		var wheelVelocity : Vector3 = get_global_point_velocity(wheel.global_transform.origin)
		
		var offset : float = wheel_height - (wheel.global_position - collision.position).length()
		offset = offset * (1 / wheel_height) # offset is 0 (not compressed) to 1 (fully compressed)
		LineDrawer.DrawLine(wheel.global_position, collision.position, Color(0, 1, 0, 1))
		
		var springwardvelocity = car_up.dot(wheelVelocity)
		var force : float = (offset * spring_strength) - (springwardvelocity * spring_damper)
		if force > self.mass * ProjectSettings.get_setting("physics/3d/default_gravity"):
			force = self.mass * ProjectSettings.get_setting("physics/3d/default_gravity")
		susp_force = car_up * force
		#apply_force(susp_force, wheel.global_transform.origin - self.global_transform.origin)
		
		#var wheel_right = (-car_left).rotated(Vector3(0, 1, 0), wheel.rotation.y).normalized()
		var wheel_right = wheel.global_transform.basis.x.normalized()
		var rightwardvelocity = wheel_right.dot(wheelVelocity)
		# we want to be pushed in the opposite direction as how much velocity is perpendicular to our wheels
		var sidewaysacceleration = ((-rightwardvelocity) * grip_amount)
		sideways_force = (sidewaysacceleration / 0.01666666) * wheel_right 
		#apply_force(sideways_force, wheel.global_transform.origin - self.global_transform.origin)
		LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (sideways_force / 100), Color(1, 0, 0))
		#LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (wheelVelocity), Color(1, 0, 0))
		
		var throttle = Input.get_axis("backward", "forward")
		accel_force = Vector3.ZERO
		var currentspeed = car_forward.dot(wheelVelocity)
		currentspeed = clamp(abs(currentspeed), 0, top_speed)
		tracked_max_turn_degrees = maxTurnDegrees * turning_radius.sample(currentspeed / top_speed)
		if(throttle != 0.0 && drive_wheel):
			var applied_torque = throttle * speed
			if throttle > 0:
				applied_torque *= engine_torque.sample(currentspeed / top_speed)
			else:
				applied_torque *= reverse_torque
			accel_force = applied_torque * car_forward
			#apply_force(accel_force, wheel.global_transform.origin - self.global_transform.origin) # shouldn't be central but debugging
			LineDrawer.DrawLine(wheel.global_position, wheel.global_position + (accel_force /100), Color(0, 0, 1))
			#LineDrawer.DrawLine(wheel.global_position, wheel.global_position + car_forward * currentspeed, Color(0, 0, 1))
		var total_force = susp_force + sideways_force + accel_force
		# for braking force, lerp currentspeed and 0 with wght depending on @export var braking_strength
		apply_force(total_force, wheel.global_transform.origin - self.global_transform.origin)

# https://www.reddit.com/r/godot/comments/eg9mdc/comment/fhf5la8
func get_global_point_velocity (point :Vector3)->Vector3:
	return linear_velocity + angular_velocity.cross(point - global_transform.origin)
