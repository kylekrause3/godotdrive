extends Camera3D

@export var FollowTarget : Node3D
@export var FollowRadius : float = 5
@export var FollowAngleDeg : float = -10
@export var CameraPositionOffset : Vector3 = Vector3(0, 0.5, 0)
@export var CameraAcceleration : float = 7.5
@export var CameraYRotAcceleration : float = 10
@export var CameraXRotAcceleration : float = 5

# @onready var InitialRotation : Vector3 = self.rotation_degrees
@onready var InitialPosition : Vector3 = self.position

@onready var lastpos : Vector3 = self.global_position
@onready var lastYRot : float = deg_to_rad(180) + FollowTarget.rotation.y
@onready var lastXRot : float = deg_to_rad(FollowAngleDeg)  - FollowTarget.rotation.x

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# position
	self.global_position = lerp(lastpos, FollowTarget.global_position + CameraPositionOffset,  CameraAcceleration * delta)
	lastpos = self.global_position
	var backward = get_backward(self.rotation)
	self.position += FollowRadius * backward
	
	# rotation
	self.rotation = Vector3(0, 0, 0)
	if (deg_to_rad(180) + FollowTarget.rotation.y) - lastYRot > deg_to_rad(180):
		lastYRot += deg_to_rad(360)
	if (deg_to_rad(180) + FollowTarget.rotation.y) - lastYRot < -deg_to_rad(180):
		lastYRot -= deg_to_rad(360)
	self.rotation.y = lerp(lastYRot, deg_to_rad(180) + FollowTarget.rotation.y, CameraYRotAcceleration * delta)
	lastYRot = deg_to_rad(180) + FollowTarget.rotation.y
	self.rotation.x = lerp(lastXRot, deg_to_rad(FollowAngleDeg)  - FollowTarget.rotation.x, CameraXRotAcceleration * delta)
	lastXRot = deg_to_rad(FollowAngleDeg)  - FollowTarget.rotation.x
	
	


func get_backward(rot : Vector3) -> Vector3:
	var ret : Vector3 = Vector3(0, 0, 1);
	ret = ret.rotated(Vector3(1, 0, 0), rot.x)
	ret = ret.rotated(Vector3(0, 1, 0), rot.y)
	return ret.normalized()
