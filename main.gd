extends Node2D

var cash: float = 500
@onready var GUI = $Gui
@onready var FACTORY_FLOOR = $FactoryFloor

@onready var CAMERA = $Camera2D
const TARGET_SPEED = 20
var target_point := Vector2(0,0)
var mouse_point: Vector2

const MIN_CAM_ZOOM = 1.5
var MAX_CAM_ZOOM = 0.25
var target_zoom: float = 0.5

var time_since_tick = 0
var TICK_LENGTH_IN_SECONDS = 1

func _ready(): 
	GUI.attempt_conveyor.connect(forward_attempt_conveyor)
	GUI.attempt_machine.connect(forward_attempt_machine)
	FACTORY_FLOOR.income_earned.connect(earn_cash)
	FACTORY_FLOOR.loose_the_game.connect(on_game_loose)
	target_point = CAMERA.position

func forward_attempt_conveyor(type: String, startpoint: Vector2i, endpoint: Vector2i):
	if type == "use": FACTORY_FLOOR.place_conveyors(startpoint, endpoint)

func forward_attempt_machine(type: String, point: Vector2i):
	FACTORY_FLOOR.place_machine(type, point)

func _process(delta):
	if Input.is_action_just_released("cancel"): 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.warp_mouse(mouse_point) 
	elif Input.is_action_just_pressed("cancel"):
		mouse_point = get_viewport().get_mouse_position()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var scroll: float = (int(Input.is_action_just_released("zoom_in")) - int(Input.is_action_just_released("zoom_out")))*0.1
	target_zoom = min(max(target_zoom+scroll, MAX_CAM_ZOOM), MIN_CAM_ZOOM)
	var zoom = lerp(CAMERA.zoom.x, target_zoom, 2.5*delta)
	CAMERA.zoom = Vector2(zoom, zoom)
	
	var diff = abs(CAMERA.position - target_point)
	var lerp_speed = diff*delta*(1-CAMERA.zoom.x)
	CAMERA.position.x = lerpf(CAMERA.position.x, target_point.x, lerp_speed.length())
	CAMERA.position.y = lerpf(CAMERA.position.y, target_point.y, lerp_speed.length())
	
	time_since_tick += delta
	if time_since_tick > TICK_LENGTH_IN_SECONDS: 
		time_since_tick -= TICK_LENGTH_IN_SECONDS
		FACTORY_FLOOR.process_world_tick(TICK_LENGTH_IN_SECONDS)

func earn_cash(amount: float):
	cash += amount
	GUI.update_cash_display(amount)

func speed_modulation(multi : float):
	TICK_LENGTH_IN_SECONDS = multi

func _input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("cancel"):
		if abs(event.relative): 
			var amount = -event.relative * get_process_delta_time()
			target_point += amount * TARGET_SPEED

func on_game_loose(fail_point: Vector2i):
	print("lost the game at: ", fail_point)
