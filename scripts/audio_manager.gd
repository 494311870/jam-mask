extends Node

## 全局音效管理器，用于跨场景音频播放和静音管理

const BGM_PATH = "res://art/audio/DavidKBD - Tropical Pack - 03 - Heartbeats - Bossanova.ogg"
const SFX_CLICK_PATH = "res://art/audio/se/Abstract2.mp3"

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var is_music_enabled: bool = true

func _ready() -> void:
	# 确保此节点可以跨场景存在
	# process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 初始化 BGM 播放器
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.volume_db = linear_to_db(0.5)
	add_child(music_player)
	
	var bgm_stream = load(BGM_PATH)
	if bgm_stream:
		music_player.stream = bgm_stream
		music_player.autoplay = false
	
	# 初始化 SFX 播放器
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	
	var sfx_stream = load(SFX_CLICK_PATH)
	if sfx_stream:
		sfx_player.stream = sfx_stream

	# 默认开始播放 BGM
	play_music()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			play_click_sfx()

func play_music() -> void:
	if not music_player.playing and is_music_enabled:
		music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_click_sfx() -> void:
	if is_music_enabled and sfx_player:
		sfx_player.play()

func toggle_music() -> bool:
	set_music_enabled(!is_music_enabled)
	return is_music_enabled

func set_music_enabled(enabled: bool) -> void:
	is_music_enabled = enabled
	if is_music_enabled:
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()
