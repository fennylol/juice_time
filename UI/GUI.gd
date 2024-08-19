extends Control

signal attempt_conveyor(type: String, startpoint: Vector2i, endpoint: Vector2i)
signal attempt_machine(type: String, point: Vector2i)

var planned_start: Vector2i
var planned_end: Vector2i
var is_dragging: bool = false
var is_selecting: bool = false

func _process(delta):
	if Input.is_action_just_pressed("use"):
		if Input.is_action_pressed("debug_place_flipper"):
			attempt_machine.emit("flipper", get_global_mouse_position())
		elif Input.is_action_pressed("debug_place_generator"):
			attempt_machine.emit("generator", get_global_mouse_position())
		elif  Input.is_action_pressed("debug_place_mixer"):
			attempt_machine.emit("mixer", get_global_mouse_position())
		else:
			planned_start = get_global_mouse_position()
			is_dragging = true

	if Input.is_action_just_released("use"):
		if is_dragging:
			planned_end = get_global_mouse_position()
			attempt_conveyor.emit("use", planned_start, planned_end)
			is_dragging = false
	
	
	if is_selecting:
		# close color/dir dialog box
		pass
	else:
		pass
	

func update_cash_display(cash: float):
	pass
