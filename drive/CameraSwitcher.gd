extends Node3D

@export var cameras : Array[Camera3D]

@export var activeCamera : int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(1, cameras.size()):
		cameras[i].current = false
		if i == activeCamera:
			cameras[i].current = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("switchCam"):
		nextCam()


func nextCam() -> void:
	cameras[activeCamera].current = false
	activeCamera += 1
	if activeCamera >= cameras.size():
		activeCamera = 0
	cameras[activeCamera].current = true
