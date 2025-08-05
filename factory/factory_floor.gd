extends Node2D

@onready var CONVEYOR_TILES:  TileMapLayer = $conveyors
@onready var AUTO_COLOR:      TileMapLayer = $auto_color
@onready var AUTO_TILES:      TileMapLayer = $auto_base
@onready var BOTTLE_COLOR:    TileMapLayer = $bottle_color
@onready var BOTTLE_TILES:    TileMapLayer = $bottle_outline
@onready var MACHINE_COLOR:   TileMapLayer = $machine_color
@onready var MACHINE_TILES:   TileMapLayer = $machine_base
@onready var GHOST_MACHINES:  TileMapLayer = $ghost_of_machine
@onready var GHOST_CONVEYORS: TileMapLayer = $ghost_of_conveyor

signal shipped_truck(value: int, amount: int)

var valid_placement := Color(Color.PALE_GREEN, 0.5)
var invalid_placement := Color(Color.PALE_VIOLET_RED, 0.5)
signal machine_hovering(valid: bool)
signal conveyor_hovering(valid: bool)
var hover_start: Vector2i

## TRUCK TIMING AND LOSE CONDITION HANDLING
signal loose_the_game(failed_truck_point: Vector2i)
var warning_state = [30,40,50,60,70,80,90]

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
signal colors(colors: Array)
enum {HUE, POSITION}
const NULL_BOTTLE_HUE = -1 #Color.BLACK
var GLOBAL_SATURATION = 0.5
var GLOBAL_LIGHTNESS = 0.5
var GLOBAL_PRECISION = 3
var LAYER_COLOR_DICT = {}
var COLOR_COMPLEXITY_DICT = {}
var last_mouse_dir := Vector2.ZERO

const TILE_ATLAS: Dictionary = {
	"bottle"       : Vector2i(0,4),
	"juice"        : Vector2i(4,3),
	"generator"    : Vector2i(0,0),
	"filler"       : Vector2i(3,0),
	"filler_color" : Vector2i(4,0),
	"flipper"      : Vector2i(1,0),
	"mixer"        : Vector2i(2,0),
	"mixer_color0" : Vector2i(5,0),
	"mixer_color1" : Vector2i(5,2),
	"mixer_spouts" : Vector2i(4,2),
	"mixer_color0_filled": Vector2i(5,1),
	"mixer_color1_filled": Vector2i(5,3),
	"warning_timer_0": Vector2i(0,5),
	"warning_timer_1": Vector2i(1,5),
	"warning_timer_2": Vector2i(2,5),
	"warning_timer_3": Vector2i(3,5),
	"warning_timer_4": Vector2i(4,5),
	"warning_timer_5": Vector2i(5,5)
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

## MACHINE STATE
var GENERATOR_STATE: Dictionary = {
	Vector2i.ZERO: {
		"time_since_generation" : 0,
		"time_out": 2,
		"generation_odds": 0.75
	}
}
var FILLER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"hue": NULL_BOTTLE_HUE
	}
}
var FLIPPER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"direction0": Vector2i.DOWN,
		"direction1": Vector2i.LEFT,
		"use_direction0": true,
		"flipping_next": false,
		"flipping_now": false
	}
}
var MIXER_STATE: Dictionary = {
	Vector2i.ZERO: {
		"hue0": NULL_BOTTLE_HUE,
		"hue1": NULL_BOTTLE_HUE,
		"hue0_filled": false,
		"hue1_filled": false,
		"outputting_now": false,
		"outputting_next": false
	}
}
var bottles_in_truck = [Vector2i(1,1),Vector2i(0,1),Vector2i(1,0),Vector2i(0,0)]
var TRUCK_STATE: Dictionary = {
	Vector2i.ZERO: {
		"hue" : NULL_BOTTLE_HUE,
		"area" : [Vector2i.ZERO],
		"filled": 0,
		"since_last_filled": 0,
		"value": 0
	}
}

#region UTILITY

func _ready():
	#find_layer_from_hue(NULL_BOTTLE_HUE)
	## CREATE AND STORE A NEW TileMapPattern OUT OF THE GIVEN TILEMAP POSITIONS
	for pat_name in patterns:
		patterns[pat_name]["pattern"] = AUTO_TILES.get_pattern(patterns[pat_name]["pos"])
		for pos in patterns[pat_name]["pos"]: AUTO_TILES.erase_cell(pos)
	
	## SET INITIAL COLOR COMPLETITY AS OKLAB HUES
	var new_color_complexity_dict_entry = {1: [0.0, 0.33, 0.66]}
	COLOR_COMPLEXITY_DICT.merge(new_color_complexity_dict_entry)
	
	## CLEAR ALL TRUCK AND MACHINE STATE DICTIONARIES
	GENERATOR_STATE.clear()
	FILLER_STATE.clear()
	FLIPPER_STATE.clear()
	MIXER_STATE.clear()
	TRUCK_STATE.clear()
	
	## PLACE TUTORIAL TILES
	var TDN = two_different_nums(2)
	var h0 = COLOR_COMPLEXITY_DICT[1][TDN[0]]
	var h1 = COLOR_COMPLEXITY_DICT[1][TDN[1]]
	set_color_complexity(mix_hues(h0, h1), 2)
	
	place_generator(Vector2i(2,-4))
	place_generator(Vector2i(-7,1))
	place_generator(Vector2i(-4,-2))
	
	place_filler(h0, Vector2i(7,-3))
	place_filler(h1, Vector2i(5, 0))
	place_filler(h0, Vector2i(-1,-1))
	place_filler(h1, Vector2i(-5, 2))
	
	place_flipper(Vector2i.RIGHT, Vector2i.DOWN, Vector2i(4,-3))
	place_mixer(h0, h1, Vector2(7,0))
	place_mixer(h1, h0, Vector2(3,-1))
	place_truck(mix_hues(h0, h1), Vector2i(3,1))
	place_basic_fillers(20)

func modulate_speed(multi : float):
	var conveyor_tileset : TileSet = CONVEYOR_TILES.tile_set

func mix_colors(c0: Color, c1: Color) -> Color: return c0.blend(Color(c1, c1.a * 0.5))
func mix_hues(h0: float, h1: float) -> float:
	## CONVERT 0-1 HUES TO 0-360 HUES SUCH THAT A0 IS ALWAYS LESS THAN OR EQUAL TO A1
	var a0: int = h0*360 if h0 <= h1 else h1*360
	var a1: int = h1*360 if h0 <= h1 else h0*360
	
	## TODO: MAKE THIS WORK WITH WRAPAROUND ANGLES.
	var a_mix = ((a0 + a1) / 2) % 360
	var h_mix: float = round_to_digit((float(a_mix) / 360.0), GLOBAL_PRECISION) 
	
	pass
	return h_mix

## GIVEN A TILEMAP POSITION "POS", RETURN THE BOTTLE AT THAT POSITION'S JUICE COLOR
#func find_color_from_pos(pos: Vector2i) -> Color:
#	for layer in range(1, BOTTLE_TILES.get_layers_count()):
#		if BOTTLE_COLOR.get_used_cells().has(pos):
#			return BOTTLE_COLOR.get_layer_modulate(layer)
#	return NULL_BOTTLE_HUE

## GIVEN A TILEMAP POSITION "POS", RETURN THE BOTTLE'S "HUE" COMPONENT OF ITS COLOR
## as above, except works with hue instead of color, and works with the new TileMapLayer nodes
func find_hue_from_pos(pos: Vector2i) -> float:
	if BOTTLE_COLOR.get_used_cells().has(pos): return BOTTLE_COLOR.get_cell_tile_data(pos).modulate.h
	else: return NULL_BOTTLE_HUE

## GIVEN A SPECIFIC COLOR, RETURN THE UNIVERSAL LAYER THAT IS ASSOCIATED WITH THAT COLOR
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
#func find_layer_from_hue(h: float) -> int:
#		if not LAYER_COLOR_DICT.has(h): 
#			var layer_index = LAYER_COLOR_DICT.keys().size()+1
#			LAYER_COLOR_DICT[h] = layer_index
#			## CREATE NEW LAYERS IN ALL APPLICABLE TILEMAPS AND MODULATE
#			BOTTLE_TILES.add_layer(layer_index)
#			MACHINE_TILES.add_layer(layer_index)
#			AUTO_TILES.add_layer(layer_index)
#			BOTTLE_TILES.set_layer_name(layer_index, str(h))
#			MACHINE_TILES.set_layer_name(layer_index, str(h))
#			AUTO_TILES.set_layer_name(layer_index, str(h))
#			if h != -1:
#				BOTTLE_TILES.set_layer_modulate(layer_index, Color.from_ok_hsl(h, GLOBAL_SATURATION, GLOBAL_LIGHTNESS))
#				MACHINE_TILES.set_layer_modulate(layer_index, Color.from_ok_hsl(h, GLOBAL_SATURATION, GLOBAL_LIGHTNESS))
#				AUTO_TILES.set_layer_modulate(layer_index, Color.from_ok_hsl(h, GLOBAL_SATURATION, GLOBAL_LIGHTNESS))
#		return LAYER_COLOR_DICT[h]

func round_to_digit(n: float, d: int) -> float: return round(n * pow(10.0, d)) / pow(10.0, d)

func angle_between(h0: float, h1: float) -> int:
	var angle1: int = h0*360 if h0 <= h1 else h1*360
	var angle2: int = h1*360 if h0 <= h1 else h0*360
	var angle1a = angle1 + 360

	return min(abs(angle2 - angle1),abs(angle1a - angle2))

# TODO: turn into a field in LAYER_COLOR_DICT
func set_color_complexity(h: float, tier: int):
	if COLOR_COMPLEXITY_DICT.keys().has(tier):
		if not COLOR_COMPLEXITY_DICT[tier].has(h):
			COLOR_COMPLEXITY_DICT[tier].append(h)
	else: 
		COLOR_COMPLEXITY_DICT[tier] = [h]

func two_different_nums(max: int) -> Array[int]:
	var rand0 = randi_range(0,max)
	var rand1 = randi_range(0,max-1)
	return [rand0, rand1 + (1 if rand0 <= rand1 else 0)]

func place_basic_fillers(r: int):
	for c in COLOR_COMPLEXITY_DICT[1]:
		var pos := Vector2i(randi_range(-r,r), randi_range(-r,r))
		if CONVEYOR_TILES.get_used_cells().has(pos) or MACHINE_TILES.get_used_cells().has(pos) or AUTO_TILES.get_used_cells().has(pos):
			while CONVEYOR_TILES.get_used_cells().has(pos) or MACHINE_TILES.get_used_cells().has(pos) or AUTO_TILES.get_used_cells().has(pos):
				pos = Vector2i(randi_range(-r,r), randi_range(-r,r))
		place_filler(c, pos)

func place_new_autotiles(level: int, r: int):
	## RANDOMIZE BASED ON LEVEL
	var complexity_cap = ceil(level/2.0)
	var cmplx0 = randi_range(1,complexity_cap-1)
	var cmplx1 = randi_range(1, complexity_cap-cmplx0)
	while not COLOR_COMPLEXITY_DICT.keys().has(cmplx0): cmplx0 = max(cmplx0 + 1, 0)   
	while not COLOR_COMPLEXITY_DICT.keys().has(cmplx1): cmplx1 = max(cmplx1 + 1, 0)
	
	var TDN: Array[int]
	if cmplx0 == cmplx1:
		TDN = two_different_nums(COLOR_COMPLEXITY_DICT[cmplx0].size()-1 )
	else:
		TDN.append(randi_range(0, COLOR_COMPLEXITY_DICT[cmplx0].size()))
		TDN.append(randi_range(0, COLOR_COMPLEXITY_DICT[cmplx1].size()))
	
	var h0: float = COLOR_COMPLEXITY_DICT[cmplx0][TDN[0]]
	var h1: float = COLOR_COMPLEXITY_DICT[cmplx1][TDN[1]]
	
	var mixed_hue: float = mix_hues(h0, h1)
	set_color_complexity(mixed_hue, cmplx0+cmplx1)
	
	## ADD NEW COLOR TO DICTIONARIES LOL
	#find_layer_from_hue(mixed_hue)
	
	# TODO check all 6 truck tiles
	var pos := Vector2i(randi_range(-r,r), randi_range(-r,r))
	if not is_safe_for_truck(pos): 
		while not is_safe_for_truck(pos): 
			pos = Vector2i(randi_range(-r,r), randi_range(-r,r))
	var truck_pos: Vector2i = pos
	
	pos = Vector2i(randi_range(-r,r), randi_range(-r,r))
	if CONVEYOR_TILES.get_used_cells().has(pos) or MACHINE_TILES.get_used_cells().has(pos) or AUTO_TILES.get_used_cells().has(pos):
		while CONVEYOR_TILES.get_used_cells().has(pos) or MACHINE_TILES.get_used_cells().has(pos) or AUTO_TILES.get_used_cells().has(pos):
			pos = Vector2i(randi_range(-r,r), randi_range(-r,r))
	
	place_filler(h0, pos)
	place_truck(mixed_hue, truck_pos)
	if level > 3 and not (randi_range(0, level) % 5): place_basic_fillers(r)

# LMAO holy based, here it is :)))
## CHECKS FOR AN EXISTING TILE AT EACH OF THE TRUCK'S 6 LOCATIONS IN THE CONVEYOR, AUTO, AND MACHINE TILEMAPS
## RETURNS TRUE ("SAFE") ONLY IF ALL 18 CHECKS RETURN FALSE
func is_safe_for_truck(pos: Vector2i): return not (CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(0,0)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(0,0)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(0,0)) or CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(1,0)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(1,0)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(1,0)) or CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(0,1)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(0,1)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(0,1)) or CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(1,1)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(1,1)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(1,1)) or CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(0,2)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(0,2)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(0,2)) or CONVEYOR_TILES.get_used_cells().has(pos + Vector2i(1,2)) or MACHINE_TILES.get_used_cells().has(pos + Vector2i(1,2)) or AUTO_TILES.get_used_cells().has(pos + Vector2i(1,2)))

func send_colors(): colors.emit(LAYER_COLOR_DICT.keys())

func _input(event):
	if event is InputEventMouseMotion:
		if abs(event.relative): 
			var amount = event.relative
			if abs(amount.x) >= abs(amount.y): 
				amount.x = amount.x / abs(amount.x)
				amount.y = 0
			else: 
				amount.y = amount.y / abs(amount.y)
				amount.x = 0
			if is_nan(amount.x): amount.x = 0
			if is_nan(amount.y): amount.y = 0
			last_mouse_dir = amount

func process_world_tick(tick_delta: float):
	## CREATE ATTEMPT ARRAYS. 
	## THESE WILL BE FILLED WITH VECTOR2I POSITIONS OF WHERE THE BOTTLES SHOULD BE MOVING TO
	var attempt_array = []
	var successful_attempts = []
	
	
	## EARN INCOME??
	for pos in TRUCK_STATE:
		## INCREASE "SINCE LAST FILLED" BY DELTA TIME (TICK LENGTH).
		## ADD WARNING_TIMER IF ITS BEEN AT LEAST 30 SECONDS AND A TIMER DOES NOT ALREADY EXIST
		TRUCK_STATE[pos]["since_last_filled"] += tick_delta
		var warning_timer_location = pos#+Vector2i.DOWN+Vector2i.DOWN
		
		## TODO: SIMPLIFY
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[0]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_0"])
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[1]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_1"])
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[2]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_2"])
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[3]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_3"])
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[4]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_4"])
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[5]:
			MACHINE_TILES.set_cell(warning_timer_location, machine_source, TILE_ATLAS["warning_timer_5"])
		
		## IF "SINCE LAST FILLED" IS GREATER THAN THE ACCEPTABLE TIME LIMIT, SEND A "LOSE THE GAME" SIGNAL
		if TRUCK_STATE[pos]["since_last_filled"] >= warning_state[6]:
			var fail_point = AUTO_TILES.map_to_local(pos)
			loose_the_game.emit(fail_point)
		
		## EMPTY TRUCK AND GIVE CASH IF IT IS FULL
		if TRUCK_STATE[pos]["filled"] == 4:
			for offset in bottles_in_truck:
				MACHINE_TILES.erase_cell(pos+offset)
				for k in LAYER_COLOR_DICT.keys():
					var layer = LAYER_COLOR_DICT[k]
					MACHINE_TILES.erase_cell(pos+offset)
			shipped_truck.emit(TRUCK_STATE[pos]["value"], 1)
			TRUCK_STATE[pos]["filled"] = 0
			TRUCK_STATE[pos]["value"] = 0
	
	## BOTTLE LOCATION CHECK LOOP
	for pos in BOTTLE_TILES.get_used_cells():
		
		## CHECK CONVEYOR DIRECTION UNDERNEATH AND CREATE A NEW ATTEMPT AT "NEXT POSITION"
		var conveyor_dir = DIR_FROM_TILE[CONVEYOR_TILES.get_cell_atlas_coords(pos)]
		var new_pos = pos + conveyor_dir
		var new_attempt = [find_hue_from_pos(pos), new_pos]
		
		
		## CHECK NEXT TILE FOR A MACHINE
		## IF MACHINE, PASS FUNCTIONALITY TO MACHINE
		if MIXER_STATE.has(new_pos):
			var mixer = MIXER_STATE[new_pos]
			var bottle_hue = find_hue_from_pos(pos)
			
			# TODO: RANDOMIZER AND COMPACT INTO ONE IFELSE
			if not mixer["hue0_filled"]:
				MACHINE_COLOR.set_cell(new_pos, 0, TILE_ATLAS["mixer_color0_filled"])
				mixer["hue0"] = bottle_hue
				mixer["hue0_filled"] = true
			elif mixer["hue0"] != bottle_hue and not mixer["hue1_filled"]: 
				MACHINE_COLOR.set_cell(new_pos, 0, TILE_ATLAS["mixer_color1_filled"])
				mixer["hue1"] = bottle_hue
				mixer["hue1_filled"] = true
			
			### PLACE MIXED COLOR WHEN ALL INPUTS FILLED
			if mixer["hue0_filled"] and mixer["hue1_filled"]:
				var output_hue = mix_hues(mixer["hue0"], mixer["hue1"])
				attempt_array.append([output_hue,new_pos])
				mixer["hue0_filled"] = false
				mixer["hue1_filled"] = false
				mixer["outputting_next"] = true
			
		elif FILLER_STATE.has(new_pos):
			## FILLERS REPLACE BOTTLE WITH A BOTTLE OF THE FILLER'S COLOR
			var fill_hue = FILLER_STATE[new_pos]["hue"]
			new_attempt = [fill_hue, new_pos]
			attempt_array.append(new_attempt)
			
		elif FLIPPER_STATE.has(new_pos):
			## ATTEMPT BOTTLE MOVE AND TOGGLE FLIPPER
			attempt_array.append(new_attempt)
			FLIPPER_STATE[new_pos]["flipping_next"] = true
			
		else: ## TRUCKS AND PLAIN CONVEYORS
			for truck in TRUCK_STATE.keys():
				if TRUCK_STATE[truck]["area"].has(new_pos): 
					## ADDS A DUPLICATE ATTEMPT THAT WILL GET REMOVED ON THE DUPLICATE CHECK LATER
					# TODO: find a better way to nullify this move
					attempt_array.append(new_attempt)
					
					## ALWAYS ADD A NON-EMPTY BOTTLE TO THE TRUCK
					if new_attempt[HUE] != NULL_BOTTLE_HUE:
						if TRUCK_STATE[truck]["filled"] < 4:
							MACHINE_TILES.set_cell(truck+bottles_in_truck[TRUCK_STATE[truck]["filled"]], bottle_source, TILE_ATLAS["bottle"])
							MACHINE_COLOR.set_cell(truck+bottles_in_truck[TRUCK_STATE[truck]["filled"]], bottle_source, TILE_ATLAS["juice"])
							TRUCK_STATE[truck]["filled"] = TRUCK_STATE[truck]["filled"] + 1
							
							## TODO: adjust the function to have a non-linear falloff
							var difference = angle_between(new_attempt[HUE], TRUCK_STATE[truck]["hue"])
							var value_added = floor((360 - difference) / 36)
							TRUCK_STATE[truck]["value"] += value_added
					
					## CHECK FOR TRUCK WARNING_TIMER AND REMOVE IF EXISTS
					## SET "SINCE LAST FILLED" TO 0
					var warning_timer_location = truck+Vector2i.DOWN+Vector2i.DOWN
					MACHINE_TILES.erase_cell(warning_timer_location)
					TRUCK_STATE[truck]["since_last_filled"] = 0
			## ELSE, ADD BOTTLE LOCATION AND COLOR TO "ATTEMPT" ARRAY
			attempt_array.append(new_attempt)
	
	## ADD BOTTLE FROM BOTTLE GENERATORS
	for pos in GENERATOR_STATE.keys(): 
		var genny = GENERATOR_STATE[pos]
		if genny["time_since_generation"] >= genny["time_out"]:
			if randf() <= genny["generation_odds"]:
				attempt_array.append([NULL_BOTTLE_HUE, pos + Vector2i.DOWN])
				genny["time_since_generation"] = -1
		genny["time_since_generation"] += 1
	
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
	BOTTLE_COLOR.clear()
	for new_bottle in successful_attempts:
		BOTTLE_TILES.set_cell(new_bottle[POSITION], bottle_source, TILE_ATLAS["bottle"])
		if new_bottle[HUE] != NULL_BOTTLE_HUE:
			BOTTLE_COLOR.set_cell(new_bottle[POSITION], bottle_source, TILE_ATLAS["juice"])
			BOTTLE_COLOR.get_cell_tile_data(new_bottle[POSITION]).modulate.h = new_bottle[HUE]
			BOTTLE_COLOR.get_cell_tile_data(new_bottle[POSITION]).modulate.s = 1.0
			BOTTLE_COLOR.get_cell_tile_data(new_bottle[POSITION]).modulate.v = 1.0
	
	## FLIP FLIPPERS IF FLIPPING
	for pos in FLIPPER_STATE:
		var flipper = FLIPPER_STATE[pos]
		if flipper["flipping_now"]:
			flipper["use_direction0"] = !flipper["use_direction0"]
			var direction = FLIPPER_STATE[pos]["direction0"] if FLIPPER_STATE[pos]["use_direction0"] else FLIPPER_STATE[pos]["direction1"]
			var tile = CONVEYOR_ATLAS[direction][MIDDLE]
			CONVEYOR_TILES.set_cell(pos, conveyor_source, tile)
			flipper["flipping_now"] = false
		if flipper["flipping_next"]:
			flipper["flipping_now"] = true
			flipper["flipping_next"] = false
	
	## CLEAR MIXER INDICATORS IF OUTPUTTING BOTTLE
	for pos in MIXER_STATE:
		var mixer = MIXER_STATE[pos]
		if mixer["outputting_now"]:
			if not mixer["hue0_filled"]: 
				MACHINE_COLOR.erase_cell(pos)
				mixer["hue0"] = NULL_BOTTLE_HUE
			if not mixer["hue1_filled"]: 
				MACHINE_COLOR.erase_cell(pos)
				mixer["hue1"] = NULL_BOTTLE_HUE
			MACHINE_COLOR.set_cell(pos, 0, TILE_ATLAS["mixer_spouts"])
			mixer["outputting_now"] = false
		if mixer["outputting_next"]:
			mixer["outputting_now"] = true
			mixer["outputting_next"] = false
	
	## SPAWN TRUCKS AND FILLERS
	pass

func clear_ghosts():
	GHOST_MACHINES.clear()
	GHOST_CONVEYORS.clear()

#endregion
#region CONVEYORS

func hover_conveyors(starting: bool, point: Vector2i):
	var pos = CONVEYOR_TILES.local_to_map(point)
	var conveyor_beneath: bool = CONVEYOR_TILES.get_used_cells().has(pos)
	var machine_beneath: bool = MACHINE_TILES.get_used_cells().has(pos)
	var autoplace_beneath: bool = AUTO_TILES.get_used_cells().has(pos)
	
	var color = invalid_placement
	if not (conveyor_beneath or machine_beneath) : color = valid_placement
	
	GHOST_CONVEYORS.clear()
	if starting: hover_start = pos
	
	var diff: Vector2i = pos - hover_start
	var direction: Vector2i = last_mouse_dir if not diff else \
							  Vector2i.LEFT if abs(diff.x) > abs(diff.y) and diff.x < 0 else \
							  Vector2i.RIGHT if abs(diff.x) > abs(diff.y) and diff.x > 0 else \
							  Vector2i.UP if abs(diff.x) < abs(diff.y) and diff.y < 0 else \
							  Vector2i.DOWN
	
	
	## SET INITIAL POSITION AND TARGET POSITION
	var curr_pos: Vector2i = hover_start
	var target_pos = Vector2i(hover_start.x, pos.y) if direction == Vector2i.UP or direction == Vector2i.DOWN else Vector2i(pos.x, hover_start.y)
	var add_one_to_target = target_pos + direction
	
	## CHECK EACH TILE BETWEEN START AND TARGET POSITION, INCLUSIVE
	## (STOP CHECKING IF YOU ARE ONE TILE PAST TARGET_POS)
	while curr_pos != add_one_to_target:
		var tile: Vector2i = CONVEYOR_ATLAS[direction][SOLO if hover_start == target_pos else START if curr_pos == hover_start else END if curr_pos == target_pos else MIDDLE]
		
		## KEEP ADDING NEW TILES AS LONG AS THERE IS NO TILE ALREADY THERE
		var tile_is_unblocked = true
		for truck in TRUCK_STATE.keys():
			if TRUCK_STATE[truck]["area"].has(curr_pos):
				tile_is_unblocked = false
		for generator in GENERATOR_STATE.keys():
			if generator == curr_pos: tile_is_unblocked = false 
		if CONVEYOR_TILES.get_cell_source_id(curr_pos) == -1 and tile_is_unblocked:
			GHOST_CONVEYORS.set_cell(curr_pos, conveyor_source, tile)
			curr_pos += direction
		else:
			## IF YOU FIND AN EXTANT TILE, GO BACK ONE, SET AN "END" TILE, AND BREAK THE LOOP
			## DO THIS ONLY IF YOU HAVE ALREADY PLACED AT LEAST ONE TILE
			if curr_pos != hover_start:
				curr_pos -= direction
				tile = CONVEYOR_ATLAS[direction][SOLO if hover_start == curr_pos else END]
				GHOST_CONVEYORS.set_cell(curr_pos, conveyor_source, tile)
			break
	
	#conveyor_hovering.emit(color == valid_placement)

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
	
	## SET INITIAflipper["use_direction0"] = !flipper["use_direction0"]L POSITION AND TARGET POSITION
	var curr_pos: Vector2i = start_pos
	var target_pos = Vector2i(start_pos.x, end_pos.y) if direction == Vector2i.UP or direction == Vector2i.DOWN else Vector2i(end_pos.x, start_pos.y)
	var add_one_to_target = target_pos + direction
	
	## CHECK EACH TILE BETWEEN START AND TARGET POSITION, INCLUSIVE
	## (STOP CHECKING IF YOU ARE ONE TILE PAST TARGET_POS)
	while curr_pos != add_one_to_target:
		var tile: Vector2i = CONVEYOR_ATLAS[direction][SOLO if start_pos == target_pos else START if curr_pos == start_pos else END if curr_pos == target_pos else MIDDLE]
		
		## KEEP ADDING NEW TILES AS LONG AS THERE IS NO TILE ALREADY THERE
		var tile_is_unblocked = true
		for truck in TRUCK_STATE.keys():
			if TRUCK_STATE[truck]["area"].has(curr_pos):
				tile_is_unblocked = false
		for generator in GENERATOR_STATE.keys():
			if generator == curr_pos: tile_is_unblocked = false 
		if CONVEYOR_TILES.get_cell_source_id(curr_pos) == -1 and tile_is_unblocked:
			CONVEYOR_TILES.set_cell(curr_pos, conveyor_source, tile)
			curr_pos += direction
		else:
			## IF YOU FIND AN EXTANT TILE, GO BACK ONE, SET AN "END" TILE, AND BREAK THE LOOP
			## DO THIS ONLY IF YOU HAVE ALREADY PLACED AT LEAST ONE TILE
			if curr_pos != start_pos:
				curr_pos -= direction
				tile = CONVEYOR_ATLAS[direction][SOLO if start_pos == curr_pos else END]
				CONVEYOR_TILES.set_cell(curr_pos, conveyor_source, tile)
			break

func erase_conveyor(global_pos: Vector2):
	var pos = CONVEYOR_TILES.local_to_map(global_pos)
	CONVEYOR_TILES.erase_cell(pos)

#endregion
#region MACHINES

func hover_machine(type: String, point: Vector2):
	var pos = MACHINE_TILES.local_to_map(point)
	if pos not in GHOST_MACHINES.get_used_cells(): GHOST_MACHINES.clear()
	
	var conveyor_beneath: bool = CONVEYOR_TILES.get_used_cells().has(pos)
	var machine_beneath: bool = MACHINE_TILES.get_used_cells().has(pos)
	var autoplace_beneath: bool = AUTO_TILES.get_used_cells().has(pos)
	var color = invalid_placement
	
	if not (machine_beneath or autoplace_beneath):
		match type:
			"generator": 
				if not conveyor_beneath: 
					color = valid_placement
			"flipper":
				if conveyor_beneath: 
					color = valid_placement
			"mixer":
				if conveyor_beneath: 
					color = valid_placement
	GHOST_MACHINES.set_cell(pos, machine_source, TILE_ATLAS[type])
	machine_hovering.emit(color == valid_placement)

func place_machine(type: String, point: Vector2, data: Array):
	var pos = MACHINE_TILES.local_to_map(point)
	var conveyor_beneath: bool = CONVEYOR_TILES.get_used_cells().has(pos)
	var success: bool = false
	match type:
		"generator": 
			if not conveyor_beneath: 
				place_generator(pos)
				success = true
		"flipper":
			if conveyor_beneath: 
				place_flipper(data[0] ,data[1] , pos)
				success = true
		"mixer":
			if conveyor_beneath: 
				place_mixer(data[0], data[1], pos)
				success = true

func place_generator(pos: Vector2i):
	MACHINE_TILES.set_cell(pos, auto_tiles_source, TILE_ATLAS["generator"])
	var new_dict_entry = {
		pos: {
			"time_since_generation" : 0,
			"time_out": 2,
			"generation_odds": .5
		}
	}
	GENERATOR_STATE.merge(new_dict_entry)

func place_filler(h: float, pos: Vector2i):
	AUTO_TILES.set_cell(pos, auto_tiles_source, TILE_ATLAS["filler"])
	AUTO_COLOR.set_cell(pos, auto_tiles_source, TILE_ATLAS["filler_color"])
	if AUTO_COLOR.get_cell_tile_data(pos) != null:
		AUTO_COLOR.get_cell_tile_data(pos).modulate.h = h
		AUTO_COLOR.get_cell_tile_data(pos).modulate.s = 1.0
		AUTO_COLOR.get_cell_tile_data(pos).modulate.v = 1.0
	print("hue: ", h)
	print("filler color: ", AUTO_COLOR.get_cell_tile_data(pos).modulate.h)
	var new_dict_entry = {
		pos: {
			"hue": h
		}
	}
	FILLER_STATE.merge(new_dict_entry)

func place_flipper(d0: Vector2i, d1: Vector2i, pos: Vector2i):
	MACHINE_TILES.set_cell(pos, machine_source, TILE_ATLAS["flipper"])
	var new_dict_entry = {
		pos: {
			"direction0": d0,
			"direction1": d1,
			"use_direction0": true,
			"flipping_now": false,
			"flipping_next": false
		}
	}
	FLIPPER_STATE.merge(new_dict_entry)

func place_mixer(h0: float, h1: float, pos: Vector2i):
	MACHINE_TILES.set_cell(pos, machine_source, TILE_ATLAS["mixer"])
	MACHINE_COLOR.set_cell(pos, 0, TILE_ATLAS["mixer_spouts"])
	var new_dict_entry = {
		pos: {
			"hue0": NULL_BOTTLE_HUE,
			"hue1": NULL_BOTTLE_HUE,
			"hue0_filled": false,
			"hue1_filled": false,
			"outputting_now": false,
			"outputting_next": false
		}
	}
	MIXER_STATE.merge(new_dict_entry)

func place_truck(h: float, pos: Vector2i):
	AUTO_TILES.set_pattern(pos, patterns["truck"]["pattern"])
	AUTO_COLOR.set_pattern(pos, patterns["truck_color"]["pattern"])
	var truck_area = [ pos , pos + Vector2i.RIGHT , pos + Vector2i.DOWN , pos + Vector2i.RIGHT + Vector2i.DOWN , pos + Vector2i.DOWN + Vector2i.DOWN , pos + Vector2i.DOWN + Vector2i.DOWN + Vector2i.RIGHT]
	var new_dict_entry = {
		pos: {
			"hue": h,
			"area": truck_area,
			"filled": 0,
			"since_last_filled": 0,
			"value": 0
		}
	}
	TRUCK_STATE.merge(new_dict_entry)

#endregion
