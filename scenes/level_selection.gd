extends CanvasLayer

signal level_selected(level_index: int)
signal back_pressed

@onready var grid_container: GridContainer = %GridContainer
@onready var btn_back: Button = %BtnBack

func _ready() -> void:
	btn_back.pressed.connect(func(): back_pressed.emit())

func setup_levels(level_paths: Array[String]) -> void:
	# 清理旧按钮
	for child in grid_container.get_children():
		child.queue_free()
	
	# 为每个关卡创建按钮
	for i in range(level_paths.size()):
		var btn = Button.new()
		var path = level_paths[i]
		var level_name = path.get_file().get_basename().replace("level_", "")
		
		btn.text = level_name
		btn.custom_minimum_size = Vector2(80, 80)
		
		btn.pressed.connect(func(): level_selected.emit(i))
		grid_container.add_child(btn)

func show_selection() -> void:
	show()

func hide_selection() -> void:
	hide()
