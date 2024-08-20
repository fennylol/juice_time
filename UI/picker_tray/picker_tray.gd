extends TextureRect

const color_button = preload("res://UI/picker_tray/color_picker_button.tscn")
const direction_button = preload("res://UI/picker_tray/direction_picker_button.tscn")

signal color0_picked(c: Color)
signal color1_picked(c: Color)
signal direction0_picked(d: Vector2i)
signal direction1_picked(d: Vector2i)

@onready var OPTION_BOX0 = $MarginContainer/HBoxContainer/option2
@onready var OPTION_BOX1 = $MarginContainer/HBoxContainer/option1


func set_colors(colors: Array):
	clear_box0()
	clear_box1()
	
	for c in colors:
		if c == Color.BLACK: continue
		var button0 = color_button.instantiate()
		var button1 = color_button.instantiate()
		
		button0.set_color(c)
		button0.picked.connect(pickedcolor0)
		OPTION_BOX0.add_child(button0)
		
		button1.set_color(c)
		button1.picked.connect(pickedcolor1)
		OPTION_BOX1.add_child(button1)

func set_directions():
	clear_box0()
	clear_box1()
	
	var button0 = direction_button.instantiate()
	var button1 = direction_button.instantiate()
	button0.picked.connect(pickeddirection0)
	button1.picked.connect(pickeddirection1)
	OPTION_BOX0.add_child(button0)
	OPTION_BOX1.add_child(button1)

func pickedcolor0(c: Color):
	color0_picked.emit(c)
	clear_box0()
	
func pickedcolor1(c: Color): 
	color1_picked.emit(c)
	clear_box1()
	
func pickeddirection0(d: Vector2i):
	direction0_picked.emit(d)
	clear_box0()
	
func pickeddirection1(d: Vector2i): 
	direction1_picked.emit(d)
	clear_box1()

func clear_box0(): for i in OPTION_BOX0.get_child_count(): OPTION_BOX0.get_child(i).queue_free()
func clear_box1(): for i in OPTION_BOX1.get_child_count(): OPTION_BOX1.get_child(i).queue_free()

