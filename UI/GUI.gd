extends Control

signal input_pressed(type: String, global_m_pos: Vector2)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("use"):
		var m_pos = get_global_mouse_position()
		input_pressed.emit("use", m_pos)

	if Input.is_action_pressed("cancel"):
		var m_pos = get_global_mouse_position()
		input_pressed.emit("cancel", m_pos)
