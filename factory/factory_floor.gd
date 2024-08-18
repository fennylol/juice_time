extends Node2D

@onready var CONVEYOR_TILES: TileMap = $conveyor_tiles
@onready var BOTTLE_TILES: TileMap = $bottle_tiles
@onready var MACHINE_TILES: TileMap = $machine_tiles
@onready var TRUCK_AND_FILLERS : TileMap = $truck_and_fillers

var patterns: Dictionary = {
	"truck" : TileMapPattern.new(),
	"bottle_filler" : TileMapPattern.new()
}

## CONVEYOR DIRECTION HANDLING
enum {MIDDLE, START, END}
var TILES: Dictionary = {
	Vector2i.RIGHT : [Vector2i(0,0), Vector2i(0,1),  Vector2i(0,2)],
	Vector2i.DOWN  : [Vector2i(0,3), Vector2i(0,4),  Vector2i(0,5)],
	Vector2i.LEFT  : [Vector2i(0,6), Vector2i(0,7),  Vector2i(0,8)],
	Vector2i.UP    : [Vector2i(0,9), Vector2i(0,10), Vector2i(0,11)]
}
var DIR_FROM_TILE: Dictionary = {
	Vector2i(-1,-1) : Vector2i.ZERO,
	Vector2i(0,0) : Vector2i.RIGHT,
	Vector2i(0,1) : Vector2i.RIGHT,
	Vector2i(0,2) : Vector2i.RIGHT,
	Vector2i(0,3) : Vector2i.DOWN,
	Vector2i(0,4) : Vector2i.DOWN,
	Vector2i(0,5) : Vector2i.DOWN,
	Vector2i(0,6) : Vector2i.LEFT,
	Vector2i(0,7) : Vector2i.LEFT,
	Vector2i(0,8) : Vector2i.LEFT,
	Vector2i(0,9) : Vector2i.UP,
	Vector2i(0,10) : Vector2i.UP,
	Vector2i(0,11) : Vector2i.UP
}

## BOTTLE STUFF (RENAME LATER)
enum {COLOR, POSITION}

## MACHINE DICTIONARIES
var MIXER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color1": Color.WHITE,
		"color2": Color.BLACK,
		"color1_filled": false,
		"color2_filled": false
	}
}
var FILLER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color": Color.WHITE
	}
}
var KICKER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"direction1": Vector2i.DOWN,
		"direction2": Vector2i.LEFT,
		"use_direction1": true
	}
}
var GENERATOR_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color" : Color.WHITE
	}
}

#region UTILITY

func _ready():
	## PATTERN SETUP - TRUCK
	var truck_poss = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,2)]
	patterns["truck"] = TRUCK_AND_FILLERS.get_pattern(0, truck_poss)
	for pos in truck_poss:
		TRUCK_AND_FILLERS.erase_cell(0, pos)
	## PATTERN SETUP - FILLER
	var filler_poss = [Vector2i(2,1),Vector2i(2,0)]
	patterns["bottle_filler"] = TRUCK_AND_FILLERS.get_pattern(0, filler_poss)
	for pos in filler_poss:
		TRUCK_AND_FILLERS.erase_cell(0, pos)
	
	MIXER_STATE.clear()
	FILLER_STATE.clear()
	KICKER_STATE.clear()
	GENERATOR_STATE.clear()
	
	spawn_bottle_generator(Color.PALE_VIOLET_RED, Vector2i(4,2))
	spawn_bottle_generator(Color.PALE_TURQUOISE, Vector2i(4,6))
	spawn_bottle_filler()
	spawn_truck()

func modulate_speed(multi : float):
	var conveyor_tileset : TileSet = CONVEYOR_TILES.tile_set

func process_world_tick():
	var attempt_array = []
	var successful_attempts = []
	
	## BOTTLE LOCATION CHECK LOOP
	for pos in BOTTLE_TILES.get_used_cells(0):
		## CHECK CONVEYOR DIRECTION UNDERNEATH AND CREATE ATTEMPT ARRAY
		var conveyor_dir = DIR_FROM_TILE[CONVEYOR_TILES.get_cell_atlas_coords(0, pos)]
		var new_pos = pos + conveyor_dir
		
		var new_attempt = [Color.WHITE, new_pos]
		### CHECK EACH LIQUID LAYER FOR A POSITION MATCH
		for layer in range(1, BOTTLE_TILES.get_layers_count()):
			if BOTTLE_TILES.get_used_cells(layer).has(pos):
				new_attempt[COLOR] = BOTTLE_TILES.get_layer_modulate(layer)
		
		## CHECK NEXT TILE FOR A MACHINE
		## IF MACHINE, PASS FUNCTIONALITY TO MACHINE
		if MIXER_STATE.has(new_pos):
			pass
		elif FILLER_STATE.has(new_pos):
			pass
		elif KICKER_STATE.has(new_pos):
			pass
		else:
			## ELSE, ADD BOTTLE LOCATION AND ARRAY TO "ATTEMPT" ARRAY
			attempt_array.append(new_attempt)
	
	## ADD BOTTLE FROM BOTTLE GENERATORS
	for gen_loc in GENERATOR_STATE.keys():
		var gen_color = GENERATOR_STATE.get(gen_loc).get("color")
		var new_attempt = [gen_color, gen_loc]
		attempt_array.append(new_attempt)
	
	## CHECK ARRAY FOR DUPLICATES
	for i in attempt_array.size():
		var attempti = attempt_array[i]
		var success = true
		for j in attempt_array.size():
			var attemptj = attempt_array[j]
			if i == j: pass
			elif attempti[POSITION] == attemptj[POSITION]:
				success = false
				break
		if success:
			successful_attempts.append(attempti)
	
	## CLEAR BOTTLES, RESET LAYER COUNT, AND PLACE ARRAY
	BOTTLE_TILES.clear()
	while BOTTLE_TILES.get_layers_count() > 1: BOTTLE_TILES.remove_layer(1)
	
	var color_dict = {}
	for new_bottle in successful_attempts:
		var layer_index: int
		
		if color_dict.has(new_bottle[COLOR]):
			layer_index = color_dict[new_bottle[COLOR]]
		else:
			layer_index = color_dict.keys().size()+1
			color_dict[new_bottle[COLOR]] = layer_index
			BOTTLE_TILES.add_layer(layer_index)
		
		BOTTLE_TILES.set_cell(0, new_bottle[POSITION], 0, Vector2.ZERO)
		BOTTLE_TILES.set_cell(layer_index, new_bottle[POSITION], 0, Vector2(1,0))
		
		#var cell_data = BOTTLE_TILES.get_cell_tile_data(layer_index, new_bottle[POSITION])
		BOTTLE_TILES.set_layer_modulate(layer_index, new_bottle[COLOR])
		pass

	
	### LATER ###
	
	## SPAWN TRUCKS AND FILLERS
	pass
	
	## EARN INCOME??
	pass


#endregion
#region CONVEYORS

func place_conveyors(startpoint: Vector2i, endpoint: Vector2i):
	## TILEMAP STUFF :/
	var source = 0
	
	## PULL START AND END POSITION INTO TILEMAP SPACE
	var start_pos: Vector2i = CONVEYOR_TILES.local_to_map(startpoint) 
	var end_pos: Vector2i = CONVEYOR_TILES.local_to_map(endpoint) 
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
		CONVEYOR_TILES.set_cell(0, curr_pos, source, tile)
		curr_pos += direction
	CONVEYOR_TILES.set_cell(0, target_pos, source, TILES[direction][END])

func erase_conveyor(global_pos: Vector2):
	var pos = CONVEYOR_TILES.local_to_map(global_pos)
	CONVEYOR_TILES.erase_cell(0, pos)

#endregion
#region MACHINES

func place_machine(pos: Vector2i, tile: int):
	#i mean its pretty self explanitory
	pass

#endregion
#region TRUCKS AND FILLERS

func spawn_bottle_generator(generator_color: Color, spawn_location : Vector2i):
	TRUCK_AND_FILLERS.set_cell(0, spawn_location, 0, Vector2i(2,2))
	var new_dict_entry = {
		spawn_location: {
			"color": generator_color
		}
	}
	GENERATOR_STATE.merge(new_dict_entry)

func spawn_bottle_filler():
	var spawn_location = Vector2i(2,2)
	TRUCK_AND_FILLERS.set_pattern(0, spawn_location, patterns["bottle_filler"])

func spawn_truck(c: Color = Color.WHITE):
	var spawn_location = Vector2i(10,7)
	TRUCK_AND_FILLERS.set_pattern(0, spawn_location, patterns["truck"])

#endregion
