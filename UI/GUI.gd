extends Control

const menu_node = preload("res://UI/menuing/main_menu.tscn")
var MAIN_MENU
@onready var MACHINE_TRAY = $CanvasLayer/machine_container/MachineTray 
@onready var CASH_LABEL = $CanvasLayer/main/header/cash_label
@onready var LEVEL_LABEL = $CanvasLayer/main/header/level_label
@onready var PICKER_TRAY = $CanvasLayer/main/body/PickerTray

signal attempt_conveyor(startpoint: Vector2i, endpoint: Vector2i)
signal attempt_machine(type: String, point: Vector2i, data: Array)
signal hover_machine(type: String, point: Vector2i)
signal hover_conveyors(start: bool, point: Vector2i)
signal clear_ghosts
signal request_colors
signal pause(state: bool)

const NULL_BOTTLE_COLOR = Color.BLACK
var color0: Color = NULL_BOTTLE_COLOR
var color1: Color = NULL_BOTTLE_COLOR
var direction0 := Vector2i.ZERO
var direction1 := Vector2i.ZERO

enum {NONE, GENERATOR, FLIPPER, MIXER, CONVEYOR}
var place_mode = NONE
var point_valid: bool = false

var machine_tray_open: bool = false
var tray_target_pos: float = 0
var machine_tray_open_time: float = 0.5

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
	
	PICKER_TRAY.color0_picked.connect(recieve_color0)
	PICKER_TRAY.color1_picked.connect(recieve_color1)
	PICKER_TRAY.direction0_picked.connect(recieve_direction0)
	PICKER_TRAY.direction1_picked.connect(recieve_direction1)
	add_child(MAIN_MENU)

func _on_viewport_size_changed():
	adjust_machine_tray_target_pos()

func toggle_machine_tray():
	set_machine_tray(!machine_tray_open)

func set_machine_tray(state: bool):
	machine_tray_open = state
	adjust_machine_tray_target_pos()

func adjust_machine_tray_target_pos():
	if machine_tray_open: tray_target_pos = 0
	else: tray_target_pos = 256
	var tween = create_tween()
	tween.tween_property(MACHINE_TRAY, "position:y", tray_target_pos, machine_tray_open_time).set_ease(Tween.EASE_IN)

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
					place_mode = NONE
					clear_ghosts.emit()
					attempt_machine.emit("generator", get_global_mouse_position(), [])
				FLIPPER:
					place_mode = NONE
					clear_ghosts.emit()
					planned_start = get_global_mouse_position()
					PICKER_TRAY.visible = true
					# when colors are recieved, the request will be sent
					PICKER_TRAY.set_directions()
				MIXER: 
					place_mode = NONE
					clear_ghosts.emit()
					planned_start = get_global_mouse_position()
					# when colors are recieved, the request will be sent
					request_colors.emit()
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
				place_mode = NONE
				clear_ghosts.emit()
	
	if Input.is_action_just_pressed("cancel"): 
		if is_dragging: is_dragging = false
		else: change_place_mode(NONE)
		clear_ghosts.emit()
	
	## REQUEST MACHINE WITH USER DATA
	if color0 != NULL_BOTTLE_COLOR and color1 != NULL_BOTTLE_COLOR:
		PICKER_TRAY.visible = false
		attempt_machine.emit("mixer", planned_start, [color0, color1])
		color0 = NULL_BOTTLE_COLOR
		color1 = NULL_BOTTLE_COLOR
		
	if direction0 != Vector2i.ZERO and direction1 != Vector2i.ZERO:
		PICKER_TRAY.visible = false
		attempt_machine.emit("flipper", planned_start, [direction0, direction1])
		direction0 = Vector2i.ZERO
		direction1 = Vector2i.ZERO


func update_cash_display(cash: float):
	var base_text: String = "cash: "
	CASH_LABEL.text = base_text + str(int(cash))

func update_level_display(level: int):
	var base_text: String = "level: "
	LEVEL_LABEL.text = base_text + str(level)


func play_pressed(): 
	MAIN_MENU.queue_free()
	pause.emit(false)

func settings_pressed():
	print("settings")


func recieve_color0(c: Color): color0 = c
func recieve_color1(c: Color): color1 = c
func recieve_direction0(d: Vector2i): direction0 = d
func recieve_direction1(d: Vector2i): direction1 = d

func recieve_colors(colors: Array): 
	PICKER_TRAY.visible = true
	PICKER_TRAY.set_colors(colors)
