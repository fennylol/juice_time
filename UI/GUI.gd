extends Control

const menu_node = preload("res://UI/menuing/main_menu.tscn")
var MAIN_MENU
@onready var MACHINE_TRAY = $CanvasLayer/HBoxContainer2/MachineTray

signal attempt_conveyor(startpoint: Vector2i, endpoint: Vector2i)
signal attempt_machine(type: String, point: Vector2i)
signal hover_machine(type: String, point: Vector2i)
signal hover_conveyors(start: bool, point: Vector2i)
signal clear_ghosts
signal pause(state: bool)

enum {NONE, GENERATOR, FLIPPER, MIXER, CONVEYOR}
var place_mode = NONE
var point_valid: bool = false

var tray_open: bool = false
var tray_target_pos: float = 0
var tray_open_time: float = 0.5

var planned_start: Vector2i
var planned_end: Vector2i
var is_dragging: bool = false
var is_selecting: bool = false

func _ready():
	adjust_machine_tray_target_pos()
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	MAIN_MENU = menu_node.instantiate()
	MAIN_MENU.play_pressed.connect(play_pressed)
	MAIN_MENU.settings_pressed.connect(settings_pressed)
	MACHINE_TRAY.open_tray.connect(toggle_machine_tray)
	MACHINE_TRAY.change_place_mode.connect(change_place_mode)
	add_child(MAIN_MENU)

func _on_viewport_size_changed():
	adjust_machine_tray_target_pos()

func toggle_machine_tray():
	set_machine_tray(!tray_open)

func set_machine_tray(state: bool):
	tray_open = state
	adjust_machine_tray_target_pos()

func adjust_machine_tray_target_pos():
	if tray_open: tray_target_pos = 0
	else: tray_target_pos = 256
	var tween = create_tween()
	tween.tween_property(MACHINE_TRAY, "position:y", tray_target_pos, tray_open_time).set_ease(Tween.EASE_IN)

func change_place_mode(mode: int):
	point_valid = mode == CONVEYOR#false
	place_mode = mode
	set_machine_tray(false)

func hover_success(success: bool): point_valid = success

func _process(delta):
	## PLACING
	if Input.is_action_just_pressed("use"):
		if point_valid:
			match place_mode:
				GENERATOR:
					attempt_machine.emit("generator", get_global_mouse_position())
				FLIPPER:
					attempt_machine.emit("flipper", get_global_mouse_position())
				MIXER:
					attempt_machine.emit("mixer", get_global_mouse_position())
				CONVEYOR:
					planned_start = get_global_mouse_position()
					is_dragging = true
	## HOVERING
	elif place_mode < CONVEYOR and place_mode > NONE:
		var type: String
		match place_mode:
			GENERATOR: type = "generator"
			FLIPPER: type = "flipper"
			MIXER: type = "mixer"
		hover_machine.emit(type, get_global_mouse_position())
	elif place_mode == CONVEYOR and not is_dragging:
		hover_conveyors.emit(true, get_global_mouse_position())
	
	
	if is_dragging:
		hover_conveyors.emit(false, get_global_mouse_position())
		
		if Input.is_action_just_released("use"):
				planned_end = get_global_mouse_position()
				attempt_conveyor.emit(planned_start, planned_end)
				is_dragging = false
	
	if Input.is_action_just_pressed("cancel"): 
		if is_dragging: is_dragging = false
		else: change_place_mode(NONE)
		clear_ghosts.emit()
	
	if is_selecting:
		# close color/dir dialog box
		pass
	else:
		pass
	

func update_cash_display(cash: float):
	pass

func play_pressed(): 
	MAIN_MENU.queue_free()
	pause.emit(false)

func settings_pressed():
	print("settings")



#func toggle_main_menu():
	#if main_menu.visible: main_menu.hide()
	#else: main_menu.show()
