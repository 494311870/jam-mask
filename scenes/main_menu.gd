extends CanvasLayer

signal play_pressed
signal level_selection_pressed
signal quit_pressed

@onready var btn_play: Button = %BtnPlay
@onready var btn_levels: Button = %BtnLevels
@onready var btn_quit: Button = %BtnQuit

@onready var level_selection: CanvasLayer = $LevelSelection

func _ready() -> void:
	btn_play.pressed.connect(_on_play_pressed)
	btn_levels.pressed.connect(_on_levels_pressed)
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	if level_selection:
		level_selection.level_selected.connect(_on_level_selected)
		level_selection.back_pressed.connect(_on_back_to_menu)
		level_selection.setup_levels(GameManager.level_paths)
		level_selection.hide()

func _on_play_pressed() -> void:
	GameManager.start_game(0)

func _on_levels_pressed() -> void:
	level_selection.show()

func _on_level_selected(index: int) -> void:
	GameManager.start_game(index)

func _on_back_to_menu() -> void:
	level_selection.hide()
