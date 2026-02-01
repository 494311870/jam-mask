class_name MainUI
extends CanvasLayer

const ICON_MUSIC_ON = preload("res://art/ui/Music-On.png")
const ICON_MUSIC_OFF = preload("res://art/ui/Music-Off.png")

@onready var btn_restart: Button = %BtnRestart
@onready var btn_menu: Button = %BtnMenu
@onready var btn_audio: Button = %BtnAudio
@onready var music_icon: TextureRect = %MusicIcon
@onready var label_hint: Label = %LabelHint

func _ready() -> void:
	btn_restart.pressed.connect(_on_btn_restart_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_btn_menu_pressed)
	btn_audio.toggled.connect(_on_btn_audio_toggled)
	
	# 初始化按钮状态
	_on_btn_audio_toggled(btn_audio.button_pressed)

func _on_btn_restart_pressed() -> void:
	var main = get_tree().get_first_node_in_group("game_manager")
	if main and main.has_method("restart_level"):
		main.restart_level()

func _on_btn_menu_pressed() -> void:
	var main = get_tree().get_first_node_in_group("game_manager")
	if main and main.has_method("show_main_menu"):
		main.show_main_menu()

func _on_btn_audio_toggled(is_on: bool) -> void:
	var main = get_tree().get_first_node_in_group("game_manager")
	if main:
		var audio_player = main.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
		if audio_player:
			audio_player.playing = is_on
	
	music_icon.texture = ICON_MUSIC_ON if is_on else ICON_MUSIC_OFF

func set_hint(text: String) -> void:
	if label_hint:
		label_hint.text = text
		label_hint.visible = not text.is_empty()
