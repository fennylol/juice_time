extends Node2D

@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor


func _ready(): 
	GUI.input_pressed.connect(forward_mous_position)


func forward_mous_position(type: String, pos: Vector2):
	if type == "use": FACTORY_FLOOR.place_conveyors([pos] as Array[Vector2])
	elif type == "cancel": FACTORY_FLOOR.erase_conveyor(pos)

func _process(delta):
	pass
