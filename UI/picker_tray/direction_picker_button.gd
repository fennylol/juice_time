extends VBoxContainer

signal picked(d: Vector2i)

func _on_up_button_pressed(): picked.emit(Vector2i.UP)
func _on_left_button_pressed(): picked.emit(Vector2i.LEFT)
func _on_right_button_pressed(): picked.emit(Vector2i.RIGHT)
func _on_down_button_pressed(): picked.emit(Vector2i.DOWN)
