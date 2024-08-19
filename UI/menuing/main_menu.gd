extends Control

signal play_pressed
signal settings_pressed



func _on_play_button_pressed(): play_pressed.emit()
func _on_settings_button_pressed(): settings_pressed.emit()
