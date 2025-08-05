extends Node2D

var req_history = [3,2]
var trucks_till_next_lvl = req_history[0]
var level: int = 1

@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor

@onready var CAMERA = $Camera2D
const TARGET_SPEED = 50
var target_point := Vector2(0,0)
var MAX_TARGET := 100

const MIN_CAM_ZOOM = 2.5
var MAX_CAM_ZOOM = 1.5 #0.5
var target_zoom: float = 0.5
const ZOOM_SPEED = 5

const SPRITE_WIDTH = 32
const LEVEL_TILE_MULTIPLIER = 3

var game_paused = true
var game_lost = false

var time_since_tick = 0
const FAST_LENGTH = 0.1
const DEFAULT_LENGTH = 1
var TICK_LENGTH_IN_SECONDS = DEFAULT_LENGTH

func _ready(): 
	set_texture_filter(CanvasItem.TEXTURE_FILTER_NEAREST)
	ship_truck(0)
	
	GUI.attempt_conveyor.connect(forward_attempt_conveyor)
	GUI.attempt_machine.connect(forward_attempt_machine)
	GUI.hover_machine.connect(forward_hover_machine)
	GUI.hover_conveyors.connect(forward_hover_conveyors)
	GUI.clear_ghosts.connect(forward_clear_ghosts)
	GUI.request_colors.connect(forward_request_colors)
	GUI.pause.connect(handle_pause)
	
	FACTORY_FLOOR.shipped_truck.connect(ship_truck)
	FACTORY_FLOOR.loose_the_game.connect(on_game_loose)
	FACTORY_FLOOR.machine_hovering.connect(forward_machine_hovering)
	FACTORY_FLOOR.colors.connect(forward_colors)
	target_point = CAMERA.position

func forward_attempt_conveyor(startpoint: Vector2i, endpoint: Vector2i): FACTORY_FLOOR.place_conveyors(startpoint, endpoint)
func forward_attempt_machine(type: String, point: Vector2i, data: Array): FACTORY_FLOOR.place_machine(type, point, data)
func forward_hover_machine(type: String, point: Vector2i): FACTORY_FLOOR.hover_machine(type, point)
func forward_hover_conveyors(starting: bool, point: Vector2i): FACTORY_FLOOR.hover_conveyors(starting, point)
func forward_clear_ghosts(): FACTORY_FLOOR.clear_ghosts()
func forward_request_colors(): FACTORY_FLOOR.send_colors()

func forward_machine_hovering(success: bool): GUI.hover_success(success)
func forward_colors(colors: Array): GUI.recieve_colors(colors)

func ship_truck(value: int, amount: int = 1):
	print("gained $", value, ".")
	trucks_till_next_lvl -= amount
	## INCREMENT LEVEL
	if trucks_till_next_lvl <= 0: 
		level += amount
		var new_req = req_history[0]+req_history[1]
		req_history[1] = req_history[0]
		req_history[0] = new_req
		trucks_till_next_lvl = new_req
		
		## SET CAM ZOOM
		var visible_tiles = (level * LEVEL_TILE_MULTIPLIER)+9
		MAX_CAM_ZOOM = calculate_zoom_for_visible_space(visible_tiles * SPRITE_WIDTH)
		target_zoom = MAX_CAM_ZOOM
		
		GUI.update_level_display(level)
		if level > 1: FACTORY_FLOOR.place_new_autotiles(level, visible_tiles/2)
	GUI.update_cash_display(trucks_till_next_lvl)

func handle_pause(state: bool):
	game_paused = state

func _input(event):
	if game_paused: return
	if event is InputEventMouseMotion and Input.is_action_pressed("cancel"):
		if abs(event.relative): 
			var amount = -event.relative * get_process_delta_time()
			
			var viewport_size = get_viewport_rect().size
			var max = (((level * LEVEL_TILE_MULTIPLIER)+9) * .75 * SPRITE_WIDTH) 
			var move: Vector2i
			
			if max <= abs(target_point.x + (amount.x * TARGET_SPEED)): move.x = target_point.x
			else: move.x = target_point.x + (amount.x * TARGET_SPEED)
			
			if max <= abs(target_point.y + (amount.y * TARGET_SPEED)): move.y = target_point.y
			else: move.y = target_point.y + (amount.y * TARGET_SPEED)
			
			target_point = move

func _process(delta):
	if game_lost: return
	if Input.is_action_just_pressed("pause"):
		game_paused = not game_paused
		GUI.toggle_paused(game_paused)
	
	if game_paused: return
	
	## ZOOM
	
	var scroll: float = (int(Input.is_action_just_released("zoom_in")) - int(Input.is_action_just_released("zoom_out")))*0.1
	target_zoom = min(max(target_zoom+scroll, MAX_CAM_ZOOM), MIN_CAM_ZOOM)
	var zoom = lerp(CAMERA.zoom.x, target_zoom, ZOOM_SPEED*delta)
	CAMERA.zoom = Vector2(zoom, zoom)
	
	## MOVE
	var diff = abs(CAMERA.position - target_point)
	var lerp_speed = diff*delta*(1-CAMERA.zoom.x)
	CAMERA.position.x = lerpf(CAMERA.position.x, target_point.x, lerp_speed.length())
	CAMERA.position.y = lerpf(CAMERA.position.y, target_point.y, lerp_speed.length())
	
	## SEND WORLD TICK
	if Input.is_action_pressed("faster"): TICK_LENGTH_IN_SECONDS = FAST_LENGTH
	else:  TICK_LENGTH_IN_SECONDS = DEFAULT_LENGTH
	
	time_since_tick += delta
	if time_since_tick > TICK_LENGTH_IN_SECONDS: 
		time_since_tick = fmod(time_since_tick,TICK_LENGTH_IN_SECONDS)
		FACTORY_FLOOR.process_world_tick(TICK_LENGTH_IN_SECONDS)


func speed_modulation(multi : float):
	TICK_LENGTH_IN_SECONDS = multi


func on_game_loose(fail_point: Vector2i):
	print("lost the game at: ", fail_point)
	game_lost = true
	game_paused = true
	GUI.toggle_paused(true)
	GUI.on_loose_game_screen()

func calculate_zoom_for_visible_space(desired_visible_space: float) -> float:
	var viewport_size = get_viewport_rect().size
	var zoom = viewport_size.y / desired_visible_space
	return zoom
