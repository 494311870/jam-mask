extends MapElement

@onready var _viewfinder_system : ViewfinderSystem = get_tree().get_first_node_in_group("viewfinder_system")

var _fixed_layer : TileMapLayer
var _terrain_layer : TileMapLayer

func _ready():
	super._ready()

	_fixed_layer = get_parent().get_node("../Fixed")
	_terrain_layer = get_parent().get_node("../Terrain")


func _input(event):
	if _viewfinder_system and _viewfinder_system.current_mode != ViewfinderSystem.Mode.INTERACT:
		return
		
	var direction = Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("move_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("move_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("move_right"):
		direction = Vector2i.RIGHT
	
	if direction != Vector2i.ZERO:
		move_player(direction)


func move_player(direction: Vector2i):
	var local_pos = tile_map_layer.to_local(global_position)
	var current_tile = tile_map_layer.local_to_map(local_pos)
	var target_tile = current_tile + direction
	
	if is_obstacle(target_tile):
		print("碰到了障碍物！坐标: ", target_tile)
		return
		
	# 如果没有障碍物，移动到目标格子
	# 必须将本地地图坐标转换回全局坐标，除非 Player 和 TileMapLayer 在同一个父节点且没有位移
	var target_local_pos = tile_map_layer.map_to_local(target_tile)
	global_position = tile_map_layer.to_global(target_local_pos)
	
	check_win_condition()


func check_win_condition():
	# 获取所有目标点
	var targets = get_tree().get_nodes_in_group("targets")
	for target in targets:
		if target is TargetPoint:
			# 检查玩家是否与目标点在同一个格子上
			var player_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(global_position))
			var target_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(target.global_position))
			
			if player_tile == target_tile:
				print("到达终点！准备进入下一关...")
				# 调用 Main 的进入下一关逻辑
				var main = get_tree().get_first_node_in_group("game_manager")
				if main and main.has_method("next_level"):
					main.call_deferred("next_level")


func is_obstacle(coords: Vector2i) -> bool:
	# 检查固定层和地形层
	for layer in [_fixed_layer, _terrain_layer]:
		var tile_data = layer.get_cell_tile_data(coords)
		if tile_data:
			var is_obs = tile_data.get_custom_data("obstacle")
			if is_obs:
				return true

	return false
