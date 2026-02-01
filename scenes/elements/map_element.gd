class_name MapElement
extends Node2D

@onready var _tile_map_layer: TileMapLayer

var tile_map_layer : TileMapLayer:
	get:
		return _tile_map_layer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_tile_map_layer = get_parent() as TileMapLayer

	# 初始时对齐到网格中心
	# 使用 to_local 确保坐标在 TileMapLayer 的本地空间内
	var local_pos = _tile_map_layer.to_local(global_position)
	var current_tile = _tile_map_layer.local_to_map(local_pos)
	global_position = _tile_map_layer.to_global(_tile_map_layer.map_to_local(current_tile))
