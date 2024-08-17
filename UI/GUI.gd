extends Control

signal attempt_conveyor(type: String, startpoint: Vector2i, endpoint: Vector2i)
var planned_start: Vector2i
var planned_end: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("use"):
		planned_start = get_global_mouse_position()

	if Input.is_action_just_released("use"):
		planned_end = get_global_mouse_position()
		attempt_conveyor.emit("use", planned_start, planned_end)


