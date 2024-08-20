extends Button

signal picked(c: Color)
var color: Color
@onready var img = $img


func set_color(c: Color): color = c
func _ready(): img.modulate = color
func _on_pressed(): picked.emit(color)
