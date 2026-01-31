extends Node2D

@onready var _tile_map_layer: TileMapLayer = %"TileMapLayer"

func _ready():
	# 初始时将玩家对齐到网格中心
	# 使用 to_local 确保坐标在 TileMapLayer 的本地空间内
	var local_pos = _tile_map_layer.to_local(global_position)
	var current_tile = _tile_map_layer.local_to_map(local_pos)
	global_position = _tile_map_layer.to_global(_tile_map_layer.map_to_local(current_tile))

func _input(event):
	var direction = Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	
	if direction != Vector2i.ZERO:
		move_player(direction)

func move_player(direction: Vector2i):
	var local_pos = _tile_map_layer.to_local(global_position)
	var current_tile = _tile_map_layer.local_to_map(local_pos)
	var target_tile = current_tile + direction
	
	if is_obstacle(target_tile):
		print("碰到了障碍物！坐标: ", target_tile)
		return
		
	# 如果没有障碍物，移动到目标格子
	# 必须将本地地图坐标转换回全局坐标，除非 Player 和 TileMapLayer 在同一个父节点且没有位移
	var target_local_pos = _tile_map_layer.map_to_local(target_tile)
	global_position = _tile_map_layer.to_global(target_local_pos)

func is_obstacle(coords: Vector2i) -> bool:
	var tile_data = _tile_map_layer.get_cell_tile_data(coords)
	if tile_data:
		var is_obs = tile_data.get_custom_data("obstacle")
		if is_obs:
			return true
	return false
