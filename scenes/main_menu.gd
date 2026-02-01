extends CanvasLayer

signal play_pressed
signal level_selection_pressed
signal quit_pressed

const ICON_MUSIC_ON = preload("res://art/ui/Music-On.png")
const ICON_MUSIC_OFF = preload("res://art/ui/Music-Off.png")

@onready var btn_play: Button = %BtnPlay
@onready var btn_levels: Button = %BtnLevels
@onready var btn_quit: Button = %BtnQuit
@onready var btn_audio: Button = %BtnAudio
@onready var music_icon: TextureRect = %MusicIcon

@onready var level_selection: CanvasLayer = $LevelSelection

func _ready() -> void:
	btn_play.pressed.connect(_on_play_pressed)
	btn_levels.pressed.connect(_on_levels_pressed)
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	btn_audio.toggled.connect(_on_btn_audio_toggled)
	
	# 初始化按钮状态
	btn_audio.button_pressed = AudioManager.is_music_enabled
	_update_audio_ui(AudioManager.is_music_enabled)
	
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

func _on_btn_audio_toggled(is_on: bool) -> void:
	AudioManager.set_music_enabled(is_on)
	_update_audio_ui(is_on)

func _update_audio_ui(is_on: bool) -> void:
	music_icon.texture = ICON_MUSIC_ON if is_on else ICON_MUSIC_OFF
