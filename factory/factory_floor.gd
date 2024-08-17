extends Node2D

@onready var conveyor_tiles: TileMap = $conveyor_tiles
enum {MIDDLE, START, END}

var TILES: Dictionary = {
	Vector2i.RIGHT : [Vector2i(0,0), Vector2i(0,1),  Vector2i(0,2)],
	Vector2i.DOWN  : [Vector2i(0,3), Vector2i(0,4),  Vector2i(0,5)],
	Vector2i.LEFT  : [Vector2i(0,6), Vector2i(0,7),  Vector2i(0,8)],
	Vector2i.UP    : [Vector2i(0,9), Vector2i(0,10), Vector2i(0,11)]
}


func _ready():
	pass 


func process_world_tick():
	# update all tile maps
	pass


func place_conveyors(startpoint: Vector2i, endpoint: Vector2i):
	## TILEMAP STUFF :/
	var source = 0
	
	## PULL START AND END POSITION INTO TILEMAP SPACE
	var start_pos: Vector2i = conveyor_tiles.local_to_map(startpoint) 
	var end_pos: Vector2i = conveyor_tiles.local_to_map(endpoint) 
	## GET THE VECTOR2 DIFFERENCE BETWEEN START AND END, AND FIND THE CARDINAL DIRECTION OF THE LINE BETWEEN
	var diff: Vector2i = endpoint - startpoint
	var direction: Vector2i = Vector2i.LEFT if abs(diff.x) >= abs(diff.y) and diff.x < 0 else \
							  Vector2i.RIGHT if abs(diff.x) > abs(diff.y) and diff.x > 0 else \
							  Vector2i.UP if abs(diff.x) <= abs(diff.y) and diff.y < 0 else \
							  Vector2i.DOWN
	
	## SET INITIAL POSITION AND TARGET POSITION
	var curr_pos: Vector2i = start_pos
	var target_pos = Vector2i(start_pos.x, end_pos.y) if direction == Vector2i.UP or direction == Vector2i.DOWN else Vector2i(end_pos.x, start_pos.y)
	
	## TODO: detect existing tiles
	while curr_pos != target_pos:
		var tile: Vector2i = TILES[direction][START if curr_pos == start_pos else MIDDLE]
		conveyor_tiles.set_cell(0, curr_pos, source, tile)
		curr_pos += direction
	conveyor_tiles.set_cell(0, target_pos, source, TILES[direction][END])


func erase_conveyor(global_pos: Vector2):
	var pos = conveyor_tiles.local_to_map(global_pos)
	conveyor_tiles.erase_cell(0, pos)

func place_machine(pos: Vector2i, tile: int):
	#i mean its pretty self explanitory
	pass
