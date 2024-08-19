extends TextureRect

signal open_tray
signal change_place_mode(mode: int)

func _on_open_button_pressed(): open_tray.emit()
func _on_generator_button_pressed(): change_place_mode.emit(1)
func _on_flipper_button_pressed(): change_place_mode.emit(2)
func _on_mixer_button_pressed(): change_place_mode.emit(3)
func _on_conveyor_button_pressed(): change_place_mode.emit(4)
