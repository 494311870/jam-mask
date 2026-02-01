class_name Level
extends Node2D

## 关卡基础类，定义关卡特定的配置

@export var available_shapes: Array[SelectorShape] = []
@export var auto_generate_walls: bool = true
@export var wall_source_id: int = 1
@export var wall_atlas_coords: Vector2i = Vector2i(1, 0)

func _ready() -> void:
	if auto_generate_walls:
		generate_outer_walls()

## 根据 Terrain 层内容自动生成 Fixed 层外墙
func generate_outer_walls() -> void:
	var terrain: TileMapLayer = get_node_or_null("Terrain") as TileMapLayer
	var fixed: TileMapLayer = get_node_or_null("Fixed") as TileMapLayer
	
	if not terrain or not fixed:
		return
	
	# 获取所有地形格子
	var terrain_cells: Array[Vector2i] = terrain.get_used_cells()
	if terrain_cells.is_empty():
		return
		
	# 使用字典记录地形格子，方便查找
	var terrain_map: Dictionary = {}
	for cell in terrain_cells:
		terrain_map[cell] = true
	
	# 8个方向，用于生成外廓
	var neighbors: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0),                   Vector2i(1, 0),
		Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
	]
	
	var wall_cells: Dictionary = {}
	for cell in terrain_cells:
		for offset in neighbors:
			var neighbor: Vector2i = cell + offset
			if not terrain_map.has(neighbor):
				wall_cells[neighbor] = true
	
	# 填充 Fixed 层。
	for cell: Vector2i in wall_cells:
		fixed.set_cell(cell, wall_source_id, wall_atlas_coords)
