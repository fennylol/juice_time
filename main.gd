extends Node2D

var cash: float = 0
var level_amount: float = 1000
var level: int = 0

@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor

@onready var CAMERA = $Camera2D
const TARGET_SPEED = 20
var target_point := Vector2(0,0)
var mouse_point: Vector2

const MIN_CAM_ZOOM = 1.5
var MAX_CAM_ZOOM
var target_zoom: float = 0.5

const SPRITE_WIDTH = 128
const LEVEL_TILE_MULTIPLIER = 2

var game_paused = true
var game_lost = false

var time_since_tick = 0
const FAST_LENGTH = 0.1
const DEFAULT_LENGTH = 1
var TICK_LENGTH_IN_SECONDS = DEFAULT_LENGTH

func _ready(): 
	set_texture_filter(CanvasItem.TEXTURE_FILTER_NEAREST)
	earn_cash(0)
	
	GUI.attempt_conveyor.connect(forward_attempt_conveyor)
	GUI.attempt_machine.connect(forward_attempt_machine)
	GUI.hover_machine.connect(forward_hover_machine)
	GUI.hover_conveyors.connect(forward_hover_conveyors)
	GUI.clear_ghosts.connect(forward_clear_ghosts)
	GUI.request_colors.connect(forward_request_colors)
	GUI.pause.connect(handle_pause)
	
	FACTORY_FLOOR.income_earned.connect(earn_cash)
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

func earn_cash(amount: float):
	cash += amount
	GUI.update_cash_display(cash)
	## INCREMENT LEVEL
	if cash >= level_amount*level: 
		level += 1
		var visible_tiles = (level * LEVEL_TILE_MULTIPLIER)+9
		MAX_CAM_ZOOM = calculate_zoom_for_visible_space(visible_tiles * SPRITE_WIDTH)
		target_zoom = MAX_CAM_ZOOM
		GUI.update_level_display(level)
		if level > 1: FACTORY_FLOOR.place_new_autotiles(level, visible_tiles/2)

func handle_pause(state: bool):
	game_paused = state

func _input(event):
	if game_paused: return
	if event is InputEventMouseMotion and Input.is_action_pressed("cancel"):
		if abs(event.relative): 
			var amount = -event.relative * get_process_delta_time()
			target_point += amount * TARGET_SPEED

func _process(delta):
	if game_lost: return
	if Input.is_action_just_pressed("pause"):
		game_paused = not game_paused
		GUI.toggle_paused(game_paused)
	
	if game_paused: return
	
	## HIDE MOUSE WHILE MOVING CAMERA
	if Input.is_action_just_released("cancel"): 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.warp_mouse(mouse_point) 
	elif Input.is_action_just_pressed("cancel"):
		mouse_point = get_viewport().get_mouse_position()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	## ZOOM
	var scroll: float = (int(Input.is_action_just_released("zoom_in")) - int(Input.is_action_just_released("zoom_out")))*0.1
	target_zoom = min(max(target_zoom+scroll, MAX_CAM_ZOOM), MIN_CAM_ZOOM)
	var zoom = lerp(CAMERA.zoom.x, target_zoom, 2.5*delta)
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
