extends Node2D

## 场景核心脚本，负责关卡加载和系统初始化

@export var debug_level : PackedScene

@onready var current_level_container: Node2D = $CurrentLevel
@onready var viewfinder_system: ViewfinderSystem = $ViewfinderSystem
@onready var main_ui: MainUI = $MainUI

var level_paths: Array[String] = []
var current_level_index: int = -1
var current_level_path: String = ""

func _ready() -> void:
	# 注册到组，方便 Player 调用
	add_to_group("game_manager")
	
	# 扫描关卡目录
	_scan_levels()

	# 如果在编辑器调试且设置了调试关卡，优先加载
	if OS.is_debug_build() and debug_level:
		load_level(debug_level.resource_path)
		return
	
	# 加载第一关
	if level_paths.size() > 0:
		load_level_by_index(0)
	else:
		push_warning("没有找到任何关卡文件！")

## 扫描关卡目录
func _scan_levels() -> void:
	level_paths.clear()
	var levels = ResourceUtility.list_files("res://content/levels/")
	for path in levels:
		if path.ends_with(".tscn") and not path.contains("_template"):
			level_paths.append(path)
	
	# 对关卡名称进行排序
	level_paths.sort()

## 进入下一关
func next_level() -> void:
	var next_index = (current_level_index + 1) % level_paths.size()
	load_level_by_index(next_index)

## 重启当前关卡
func restart_level() -> void:
	print("[Main] 重启当前关卡: ", current_level_path)
	if current_level_path != "":
		load_level(current_level_path)
	elif current_level_index != -1:
		load_level_by_index(current_level_index)

## 按索引加载关卡
func load_level_by_index(index: int) -> void:
	if index < 0 or index >= level_paths.size():
		return
		
	current_level_index = index
	load_level(level_paths[index])

## 动态加载关卡
func load_level(level_path: String) -> void:
	print("[Main] 加载关卡: ", level_path)
	current_level_path = level_path
	
	# 清理当前关卡并重置容器位置
	current_level_container.position = Vector2.ZERO
	for child in current_level_container.get_children():
		child.queue_free()
	
	# 加载新关卡
	var level_scene = load(level_path)
	if not level_scene:
		push_error("无法加载关卡文件: " + level_path)
		return
		
	var level_instance = level_scene.instantiate()
	current_level_container.add_child(level_instance)
	
	# 初始化视图系统
	_setup_systems(level_instance)
	
	# 居中显示关卡
	call_deferred("center_level")

## 居中显示当前关卡
func center_level() -> void:
	# 查找容器中的最后一个孩子（即刚加载的关卡，避免 queue_free 延迟导致取到旧关卡）
	var level = current_level_container.get_child(current_level_container.get_child_count() - 1) if current_level_container.get_child_count() > 0 else null
	if not level:
		return
		
	# 只计算 Terrain 层的内容进行居中
	var terrain = level.get_node_or_null("Terrain") as TileMapLayer
	if not terrain or not terrain.tile_set:
		push_warning("[Main] 关卡中缺少名为 Terrain 的 TileMapLayer，无法自动居中")
		return
		
	var combined_rect = terrain.get_used_rect()
	if combined_rect.size == Vector2i.ZERO:
		return
		
	var tile_size = Vector2(terrain.tile_set.tile_size)
	
	# 关卡内容在 Level 节点坐标系下的像素矩形范围
	var content_pos_px = Vector2(combined_rect.position) * tile_size
	var content_size_px = Vector2(combined_rect.size) * tile_size
	
	# 获取视口（窗口）的显示区域大小
	var viewport_size = get_viewport_rect().size
	
	# 考虑 UI 遮挡后的可用区域 (左侧预览 220px, 顶部信息条 60px)
	var ui_offset_left = 0.0
	var ui_offset_top = 0.0
	
	if viewfinder_system and not viewfinder_system.active_shapes.is_empty():
		# ui_offset_left = 220.0
		ui_offset_left = 0
		# ui_offset_top = 60.0
		ui_offset_top = 0

	
	# 计算在剩余可用空间内居中所需的偏移
	# 公式: target = (viewport + ui_offset - content_size) / 2 - content_pos
	var target_pos = (viewport_size + Vector2(ui_offset_left, ui_offset_top) - content_size_px) / 2.0 - content_pos_px
	
	# 应用到容器
	current_level_container.position = target_pos
	
	# 打印调试信息
	print("Viewport Size: ", viewport_size)
	print("Terrain Bounds: ", combined_rect, " (px: ", content_pos_px, ", ", content_size_px, ")")
	print("Calculated Container Position: ", target_pos)

func _setup_systems(level: Node2D) -> void:
	var terrain = level.get_node_or_null("Terrain")
	var elements = level.get_node_or_null("Elements")
	var shapes: Array[SelectorShape] = []
	
	if level is Level:
		shapes = level.available_shapes
		if main_ui:
			main_ui.set_hint(level.level_hint)
	
	if viewfinder_system:
		viewfinder_system.setup_layers(terrain, elements, shapes)
