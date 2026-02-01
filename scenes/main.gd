extends Node2D

## 场景核心脚本，负责关卡加载和系统初始化

@onready var current_level_container: Node2D = $CurrentLevel
@onready var viewfinder_system: ViewfinderSystem = $ViewfinderSystem

var level_paths: Array[String] = []
var current_level_index: int = -1

func _ready() -> void:
	# 注册到组，方便 Player 调用
	add_to_group("game_manager")
	
	# 扫描关卡目录
	_scan_levels()
	
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
	# 清理当前关卡
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
	var level = current_level_container.get_child(0) if current_level_container.get_child_count() > 0 else null
	if not level:
		return
		
	var terrain = level.get_node_or_null("Terrain") as TileMapLayer
	if not terrain:
		return
		
	var used_rect = terrain.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return
		
	# 使用最直观的坐标计算方式
	var tile_size = Vector2(terrain.tile_set.tile_size)
	
	# 关卡内容在 Terrain 节点坐标系下的像素矩形范围
	# used_rect.position 是起始格子坐标，used_rect.size 是格子数量
	var content_pos_px = Vector2(used_rect.position) * tile_size
	var content_size_px = Vector2(used_rect.size) * tile_size
	
	# 获取视口（窗口）的显示区域大小
	var viewport_size = get_viewport_rect().size
	
	# 计算让内容居中所需的偏移：
	# 1. (viewport_size - content_size_px) / 2.0 是让一个 0,0 起始的矩形居中的位置
	# 2. 减去 content_pos_px 是为了抵消地图瓦片本身可能存在的坐标偏移（比如从 10,10 开始画的地图）
	var target_pos = (viewport_size - content_size_px) / 2.0 - content_pos_px
	
	# 应用到容器
	current_level_container.position = target_pos
	
	# 打印调试信息（可选，如果还不对可以检查此输出）
	print("Viewport Size: ", viewport_size)
	print("Content Rect: ", content_pos_px, " size: ", content_size_px)
	print("Calculated Position: ", target_pos)

func _setup_systems(level: Node2D) -> void:
	var terrain = level.get_node_or_null("Terrain")
	var elements = level.get_node_or_null("Elements")
	
	if viewfinder_system:
		viewfinder_system.setup_layers(terrain, elements)
