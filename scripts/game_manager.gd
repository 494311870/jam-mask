extends Node

## 全局游戏管理器，负责关卡数据检索和跨场景状态管理

var level_paths: Array[String] = []
var current_level_index: int = -1

func _ready() -> void:
	_scan_levels()

## 扫描关卡目录
func _scan_levels() -> void:
	level_paths.clear()
	# 假设 ResourceUtility 是静态工具类，如果不是则使用 DirAccess
	var levels = ResourceUtility.list_files("res://content/levels/")
	for path in levels:
		if path.ends_with(".tscn") and not path.contains("_template"):
			level_paths.append(path)
	
	# 对关卡名称进行排序
	level_paths.sort()

func start_game(index: int = 0) -> void:
	current_level_index = index
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_current_level_path() -> String:
	if current_level_index >= 0 and current_level_index < level_paths.size():
		return level_paths[current_level_index]
	return ""
