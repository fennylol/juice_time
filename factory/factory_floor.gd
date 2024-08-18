extends Node2D

@onready var CONVEYOR_TILES: TileMap = $conveyor_tiles
@onready var BOTTLE_TILES: TileMap = $bottle_tiles
@onready var MACHINE_TILES: TileMap = $machine_tiles
@onready var AUTO_TILES : TileMap = $auto_tiles



## TILEMAP SOURCES
var conveyor_source = 0
var bottle_source = 0
var machine_source = 0
var auto_tiles_source = 0

## CONVEYOR DIRECTION HANDLING
enum {MIDDLE, START, END, SOLO}
const CONVEYOR_ATLAS: Dictionary = {
	Vector2i.RIGHT : [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(0,3)],
	Vector2i.LEFT  : [Vector2i(0,4), Vector2i(0,5), Vector2i(0,6), Vector2i(0,7)],
	Vector2i.DOWN  : [Vector2i(0,8), Vector2i(0,9), Vector2i(0,10), Vector2i(0,11)],
	Vector2i.UP    : [Vector2i(0,12), Vector2i(0,13), Vector2i(0,14), Vector2i(0,15)]
}
const DIR_FROM_TILE: Dictionary = {
	Vector2i(-1,-1) : Vector2i.ZERO,
	Vector2i(0,0)   : Vector2i.RIGHT,
	Vector2i(0,1)   : Vector2i.RIGHT,
	Vector2i(0,2)   : Vector2i.RIGHT,
	Vector2i(0,3)   : Vector2i.RIGHT,
	Vector2i(0,4)   : Vector2i.LEFT,
	Vector2i(0,5)   : Vector2i.LEFT,
	Vector2i(0,6)   : Vector2i.LEFT,
	Vector2i(0,7)   : Vector2i.LEFT,
	Vector2i(0,8)   : Vector2i.DOWN,
	Vector2i(0,9)   : Vector2i.DOWN,
	Vector2i(0,10)  : Vector2i.DOWN,
	Vector2i(0,11)  : Vector2i.DOWN,
	Vector2i(0,12)  : Vector2i.UP,
	Vector2i(0,13)  : Vector2i.UP,
	Vector2i(0,14)  : Vector2i.UP,
	Vector2i(0,15)  : Vector2i.UP
}


## TILE AND COLOR DATA 
enum {COLOR, POSITION}
const NULL_BOTTLE_COLOR = Color.BLACK
var LAYER_COLOR_DICT = {}

const TILE_ATLAS: Dictionary = {
	"bottle"      : Vector2i(0,0),
	"juice"       : Vector2i(1,0),
	"generator"   : Vector2i(0,0),
	"filler"      : Vector2i(4,0),
	"filler_color": Vector2i(5,0),
	"flipper"     : Vector2i(0,1),
	"flipped"     : Vector2i(0,0),
	"mixer"       : Vector2i(1,0),
	"mixer_color0": Vector2i(0,0),
	"mixer_color1": Vector2i(0,0),
}
var patterns: Dictionary = {
	"truck" : {
		"pos": [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,2)],
		"pattern": TileMapPattern.new()
	},
	"truck_color" : {
		"pos": [Vector2i(0,3),Vector2i(1,3),Vector2i(0,4),Vector2i(1,4),Vector2i(0,5),Vector2i(1,5)],
		"pattern": TileMapPattern.new()
	}
}
#var patterns: Dictionary = {
	#"truck" : TileMapPattern.new(),
	#"bottle_filler" :TileMapPattern.new()
#}

## MACHINE STATE
var GENERATOR_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color" : NULL_BOTTLE_COLOR
	}
}
var FILLER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color": NULL_BOTTLE_COLOR
	}
}
var FLIPPER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"direction1": Vector2i.DOWN,
		"direction2": Vector2i.LEFT,
		"use_direction1": true
	}
}
var MIXER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color1": NULL_BOTTLE_COLOR,
		"color2": NULL_BOTTLE_COLOR,
		"color1_filled": false,
		"color2_filled": false
	}
}
var TRUCK_STATE: Dictionary = {
	Vector2i.ZERO: {
		"color" : NULL_BOTTLE_COLOR,
		"area" : [Vector2i.ZERO],
		"filled": 0
	}
}

#region UTILITY

func _ready():
	## CREATE AND STORE A NEW TileMapPattern OUT OF THE GIVEN TILEMAP POSITIONS
	for pat_name in patterns:
		patterns[pat_name]["pattern"] = AUTO_TILES.get_pattern(0, patterns[pat_name]["pos"])
		for pos in patterns[pat_name]["pos"]: AUTO_TILES.erase_cell(0, pos)
	
	
	GENERATOR_STATE.clear()
	FILLER_STATE.clear()
	FLIPPER_STATE.clear()
	MIXER_STATE.clear()
	TRUCK_STATE.clear()

	
	var c1 = Color.PALE_TURQUOISE
	var c2 = Color.CORNFLOWER_BLUE
	place_bottle_generator(c1, Vector2i(4,2))
	place_bottle_generator(c2, Vector2i(4,6))
	place_bottle_filler(c1, Vector2i(2,2))
	place_truck(c2, Vector2i(10,7))
	place_mixer(c1, c2, Vector2(4,4))
	place_flipper(Vector2i.DOWN, Vector2i(8,4))

func modulate_speed(multi : float):
	var conveyor_tileset : TileSet = CONVEYOR_TILES.tile_set

## GIVEN A TILEMAP POSITION "POS", RETURN THE BOTTLE AT THAT POSITION'S JUICE COLOR
func find_color_from_pos(pos: Vector2i) -> Color:
	for layer in range(1, BOTTLE_TILES.get_layers_count()):
		if BOTTLE_TILES.get_used_cells(layer).has(pos):
			return BOTTLE_TILES.get_layer_modulate(layer)
	return NULL_BOTTLE_COLOR

func find_layer_from_color(c: Color) -> int:
		if not LAYER_COLOR_DICT.has(c): 
			var layer_index = LAYER_COLOR_DICT.keys().size()+1
			LAYER_COLOR_DICT[c] = layer_index
			## CREATE NEW LAYERS IN ALL APPLICABLE TILEMAPS AND MODULATE
			BOTTLE_TILES.add_layer(layer_index)
			MACHINE_TILES.add_layer(layer_index)
			AUTO_TILES.add_layer(layer_index)
			BOTTLE_TILES.set_layer_modulate(layer_index, c)
			MACHINE_TILES.set_layer_modulate(layer_index, c)
			AUTO_TILES.set_layer_modulate(layer_index, c)
		return LAYER_COLOR_DICT[c]

func process_world_tick():
	## CREATE ATTEMPT ARRAYS. 
	## THESE WILL BE FILLED WITH VECTOR2I POSITIONS OF WHERE THE BOTTLES SHOULD BE MOVING TO
	var attempt_array = []
	var successful_attempts = []
	
	## BOTTLE LOCATION CHECK LOOP
	for pos in BOTTLE_TILES.get_used_cells(0):
		
		## CHECK CONVEYOR DIRECTION UNDERNEATH AND CREATE A NEW ATTEMPT AT "NEXT POSITION"
		var conveyor_dir = DIR_FROM_TILE[CONVEYOR_TILES.get_cell_atlas_coords(0, pos)]
		var new_pos = pos + conveyor_dir
		var new_attempt = [find_color_from_pos(pos), new_pos]
		
		
		## CHECK NEXT TILE FOR A MACHINE
		## IF MACHINE, PASS FUNCTIONALITY TO MACHINE
		if MIXER_STATE.has(new_pos):
			var mixer = MIXER_STATE[new_pos]
			var bottle_color = find_color_from_pos(pos)
			## VERIFY THAT THE INPUT COLOR IS CORRECT
			if bottle_color == mixer["color1"] and not mixer["color1_filled"]: mixer["color1_filled"] = true
			elif bottle_color == mixer["color2"] and not mixer["color2_filled"]: mixer["color2_filled"] = true
			## PLACE MIXED COLOR
			if mixer["color1_filled"] and mixer["color2_filled"]:
				var output_color = mixer["color1"].blend(Color(mixer["color2"], mixer["color2"].a * 0.5))
				attempt_array.append([output_color,new_pos])
				mixer["color1_filled"] = false
				mixer["color2_filled"] = false
			
		elif FILLER_STATE.has(new_pos):
			## FILLERS REPLACE BOTTLE WITH A BOTTLE OF THE FILLER'S COLOR
			var fill_color = FILLER_STATE[new_pos]["color"]
			new_attempt = [fill_color, new_pos]
			attempt_array.append(new_attempt)
			
		elif FLIPPER_STATE.has(new_pos):
			## ATTEMPT BOTTLE MOVE AND TOGGLE FLIPPER
			attempt_array.append(new_attempt)
			FLIPPER_STATE[new_pos]["use_direction1"] = !FLIPPER_STATE[new_pos]["use_direction1"]
			## SET DIRECTION OF UNDERLYING BELT
			var direction = FLIPPER_STATE[new_pos]["direction1"] if FLIPPER_STATE[new_pos]["use_direction1"] else FLIPPER_STATE[new_pos]["direction2"]
			var tile = CONVEYOR_ATLAS[direction][MIDDLE]
			CONVEYOR_TILES.set_cell(0, new_pos, conveyor_source, tile)
			
		else:
			for truck in TRUCK_STATE.keys():
				if TRUCK_STATE[truck]["area"].has(new_pos): 
					# TODO: find a better way to nullify this move
					attempt_array.append(new_attempt)
					if TRUCK_STATE[truck]["color"] == find_color_from_pos(pos):
						# TODO: fill truck with FAKE bottle sprite
						print("bottle in truke")
			## ELSE, ADD BOTTLE LOCATION AND COLOR TO "ATTEMPT" ARRAY
			attempt_array.append(new_attempt)
	
	## ADD BOTTLE FROM BOTTLE GENERATORS
	for gen_loc in GENERATOR_STATE.keys():
		var gen_color = GENERATOR_STATE[gen_loc]["color"]
		var new_attempt = [gen_color, gen_loc]
		attempt_array.append(new_attempt)
	
	## CHECK ATTEMPT ARRAY FOR DUPLICATES.
	## ANY NON-DUPLICATES ARE ADDED TO "SUCCESSFUL_ATTEMPTS"
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
	
	## CLEAR BOTTLE TILEMAP AND PLACE NEW BOTTLE FOR EACH SUCCESSFUL ATTEMPT IN APPROPRIATE LAYER
	BOTTLE_TILES.clear()
	for new_bottle in successful_attempts:
		var layer_index = find_layer_from_color(new_bottle[COLOR])
		BOTTLE_TILES.set_cell(0, new_bottle[POSITION], bottle_source, TILE_ATLAS["bottle"])
		BOTTLE_TILES.set_cell(layer_index, new_bottle[POSITION], bottle_source, TILE_ATLAS["juice"])
	
	## SPAWN TRUCKS AND FILLERS
	pass
	
	## EARN INCOME??
	pass

#endregion
#region CONVEYORS

func place_conveyors(startpoint: Vector2i, endpoint: Vector2i):
	
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
	var add_one_to_target = target_pos + direction
	
	## CHECK EACH TILE BETWEEN START AND TARGET POSITION, INCLUSIVE
	## (STOP CHECKING IF YOU ARE ONE TILE PAST TARGET_POS)
	while curr_pos != add_one_to_target:
		var tile: Vector2i = CONVEYOR_ATLAS[direction][START if curr_pos == start_pos else END if curr_pos == target_pos else MIDDLE]
		## KEEP ADDING NEW TILES AS LONG AS THERE IS NO TILE ALREADY THERE
		if CONVEYOR_TILES.get_cell_source_id(0,curr_pos) == -1:
			CONVEYOR_TILES.set_cell(0, curr_pos, conveyor_source, tile)
			curr_pos += direction
		else:
			## IF YOU FIND AN EXTANT TILE, GO BACK ONE, SET AN "END" TILE, AND BREAK THE LOOP
			## DO THIS ONLY IF YOU HAVE ALREADY PLACED AT LEAST ONE TILE
			if curr_pos != start_pos:
				curr_pos -= direction
				tile = CONVEYOR_ATLAS[direction][END]
				CONVEYOR_TILES.set_cell(0, curr_pos, conveyor_source, tile)
			break

func erase_conveyor(global_pos: Vector2):
	var pos = CONVEYOR_TILES.local_to_map(global_pos)
	CONVEYOR_TILES.erase_cell(0, pos)

#endregion
#region MACHINES

func place_machine(pos: Vector2i, tile: int):
	#i mean its pretty self explanitory
	pass

func place_bottle_generator(c: Color, pos: Vector2i):
	MACHINE_TILES.set_cell(0, pos, auto_tiles_source, TILE_ATLAS["generator"])
	var new_dict_entry = {
		pos: {
			"color": c
		}
	}
	GENERATOR_STATE.merge(new_dict_entry)

func place_bottle_filler(c: Color, pos: Vector2i):
	AUTO_TILES.set_cell(0, pos, auto_tiles_source, TILE_ATLAS["filler"])
	AUTO_TILES.set_cell(find_layer_from_color(c), pos, auto_tiles_source, TILE_ATLAS["filler_color"])
	var new_dict_entry = {
		pos: {
			"color": c
		}
	}
	FILLER_STATE.merge(new_dict_entry)

func place_flipper(d: Vector2i, pos: Vector2i):
	MACHINE_TILES.set_cell(0, pos, machine_source, TILE_ATLAS["flipper"])
	var new_dict_entry = {
		pos: {
			"direction1": DIR_FROM_TILE[CONVEYOR_TILES.get_cell_atlas_coords(0, pos)],
			"direction2": d,
			"use_direction1": true
		}
	}
	FLIPPER_STATE.merge(new_dict_entry)


func place_mixer(c1: Color, c2: Color, pos: Vector2i):
	MACHINE_TILES.set_cell(0, pos, machine_source, TILE_ATLAS["mixer"])
	# TODO: set LEDs
	var new_dict_entry = {
		pos: {
			"color1": c1,
			"color2": c2,
			"color1_filled": false,
			"color2_filled": false
		}
	}
	MIXER_STATE.merge(new_dict_entry)

func place_truck(c: Color, pos: Vector2i):
	AUTO_TILES.set_pattern(0, pos, patterns["truck"]["pattern"])
	AUTO_TILES.set_pattern(find_layer_from_color(c), pos, patterns["truck_color"]["pattern"])
	var truck_area = [ pos , pos + Vector2i.RIGHT , pos + Vector2i.DOWN , pos + Vector2i.RIGHT + Vector2i.DOWN , pos + Vector2i.DOWN + Vector2i.DOWN , pos + Vector2i.DOWN + Vector2i.DOWN + Vector2i.RIGHT]
	var new_dict_entry = {
		pos: {
			"color": c,
			"area": truck_area,
			"filled": 0
		}
	}
	TRUCK_STATE.merge(new_dict_entry)

#endregion
