extends MapElement

var _terrain_layer : TileMapLayer


func _ready():
	super._ready()

	_terrain_layer = get_parent().get_node("%Terrain")

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
				print("到达终点！准备重载场景/进入下一关...")
				# 这里可以根据需要切换场景
				# get_tree().reload_current_scene() 
				# 或者切换到下一关
				# get_tree().change_scene_to_file("res://scenes/level_2.tscn")
				# 暂时先用重载当前场景作为演示
				call_deferred("next_level")


func next_level():
	# 这里的逻辑可以根据你的关卡管理系统来写
	get_tree().reload_current_scene()


func is_obstacle(coords: Vector2i) -> bool:
	var tile_data = _terrain_layer.get_cell_tile_data(coords)
	if tile_data:
		var is_obs = tile_data.get_custom_data("obstacle")
		if is_obs:
			return true
	return false
