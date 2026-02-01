extends Node2D

## 场景核心脚本，负责关卡加载和系统初始化

@export var debug_level : PackedScene

@onready var current_level_container: Node2D = $CurrentLevel
@onready var viewfinder_system: ViewfinderSystem = $ViewfinderSystem

var level_paths: Array[String] = []
var current_level_index: int = -1

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

## 按索引加载关卡
func load_level_by_index(index: int) -> void:
	if index < 0 or index >= level_paths.size():
		return
		
	current_level_index = index
	load_level(level_paths[index])

## 动态加载关卡
func load_level(level_path: String) -> void:
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
		
	# 查找所有 TileMapLayer 以确定地图总边界
	var layers = level.find_children("", "TileMapLayer", true, false)
	if layers.is_empty():
		return
		
	var combined_rect: Rect2i
	var has_rect = false
	
	for layer in layers:
		if layer is TileMapLayer:
			var rect = layer.get_used_rect()
			if rect.size == Vector2i.ZERO:
				continue
			if not has_rect:
				combined_rect = rect
				has_rect = true
			else:
				combined_rect = combined_rect.merge(rect)
	
	if not has_rect:
		return
		
	# 获取第一个有内容的层的图块大小（假设所有层一致）
	var first_layer: TileMapLayer = null
	for layer in layers:
		if layer is TileMapLayer and layer.tile_set:
			first_layer = layer
			break
			
	if not first_layer:
		return
		
	var tile_size = Vector2(first_layer.tile_set.tile_size)
	
	# 关卡内容在 Level 节点坐标系下的像素矩形范围
	var content_pos_px = Vector2(combined_rect.position) * tile_size
	var content_size_px = Vector2(combined_rect.size) * tile_size
	
	# 获取视口（窗口）的显示区域大小
	var viewport_size = get_viewport_rect().size
	
	# 计算让内容居中所需的偏移
	var target_pos = (viewport_size - content_size_px) / 2.0 - content_pos_px
	
	# 应用到容器
	current_level_container.position = target_pos
	
	# 打印调试信息
	print("Viewport Size: ", viewport_size)
	print("Level Bounds: ", combined_rect, " (px: ", content_pos_px, ", ", content_size_px, ")")
	print("Calculated Container Position: ", target_pos)

func _setup_systems(level: Node2D) -> void:
	var terrain = level.get_node_or_null("Terrain")
	var elements = level.get_node_or_null("Elements")
	var shapes: Array[SelectorShape] = []
	
	if level is Level:
		shapes = level.available_shapes
	
	if viewfinder_system:
		viewfinder_system.setup_layers(terrain, elements, shapes)
