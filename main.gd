extends Node2D

@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor


func _ready(): 
	GUI.attempt_conveyor.connect(forward_attempt_conveyor)


func forward_attempt_conveyor(type: String, startpoint: Vector2i, endpoint: Vector2i):
	if type == "use": FACTORY_FLOOR.place_conveyors(startpoint, endpoint)
	#elif type == "cancel": FACTORY_FLOOR.erase_conveyor(pos)

func _process(delta):
	pass
