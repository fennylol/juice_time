extends Node2D

@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor
var time_since_tick = 0
var TICK_LENGTH_IN_SECONDS = 1

func _ready(): 
	GUI.attempt_conveyor.connect(forward_attempt_conveyor)

func forward_attempt_conveyor(type: String, startpoint: Vector2i, endpoint: Vector2i):
	if type == "use": FACTORY_FLOOR.place_conveyors(startpoint, endpoint)
	#elif type == "cancel": FACTORY_FLOOR.erase_conveyor(pos)

func _process(delta):
	time_since_tick += delta
	if time_since_tick > TICK_LENGTH_IN_SECONDS: 
		time_since_tick -= TICK_LENGTH_IN_SECONDS
		FACTORY_FLOOR.process_world_tick()

func speed_modulation(multi : float):
	TICK_LENGTH_IN_SECONDS = multi
	
