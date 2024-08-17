extends Node2D

@onready var conveyor_tiles = $conveyor_tiles

func _ready():
	pass 


func process_world_tick():
	# update all tile maps
	pass


func place_conveyors(new_conveyors: Array[Vector2]):
	for global_pos in new_conveyors:
		var pos = conveyor_tiles.local_to_map(global_pos)
		var source = 0
		var tile := Vector2(0,0)
		conveyor_tiles.set_cell(0, pos, source, tile)


func erase_conveyor(global_pos: Vector2):
	var pos = conveyor_tiles.local_to_map(global_pos)
	conveyor_tiles.erase_cell(0, pos)

func place_machine(pos: Vector2i, tile: int):
	#i mean its pretty self explanitory
	pass
