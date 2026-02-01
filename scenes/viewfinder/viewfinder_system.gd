class_name ViewfinderSystem
extends Node2D

enum Mode { INTERACT, SELECT, MOVE }

@export var terrain_layer: TileMapLayer
@export var elements_layer: TileMapLayer

var current_mode: Mode = Mode.INTERACT:
	set(value):
		current_mode = value
		_on_mode_changed()

var selection_start: Vector2i
var selection_end: Vector2i
var is_selecting: bool = false

# Array of TileDataInfo or similar
var copied_tiles: Array = []
var selection_rect: Rect2i
var preview_layer: TileMapLayer
var overlay_layer: Node2D

@onready var btn_interact: Button = %BtnInteract
@onready var btn_select: Button = %BtnSelect
@onready var btn_move: Button = %BtnMove
@onready var label_status: Label = %LabelStatus
@onready var tip_ui: TipUI = %TipUI

func _ready() -> void:
	if terrain_layer or elements_layer:
		setup_layers(terrain_layer, elements_layer)
	
	btn_interact.pressed.connect(func(): current_mode = Mode.INTERACT)
	btn_select.pressed.connect(func(): current_mode = Mode.SELECT)
	btn_move.pressed.connect(func(): current_mode = Mode.MOVE)

## 设置当前操作的地图层
func setup_layers(terrain: TileMapLayer, elements: TileMapLayer) -> void:
	terrain_layer = terrain
	elements_layer = elements
	
	if terrain_layer:
		_setup_preview_layer()
	
	current_mode = Mode.INTERACT

func _on_mode_changed():
	is_selecting = false
	queue_redraw()
	if overlay_layer:
		overlay_layer.queue_redraw()
	
	if current_mode == Mode.MOVE and copied_tiles.size() > 0:
		_update_preview_layer_cells()
		preview_layer.show()
	else:
		if preview_layer:
			preview_layer.hide()

	match current_mode:
		Mode.INTERACT:
			label_status.text = "当前模式: 交互 (可以使用方向键移动)"
		Mode.SELECT:
			label_status.text = "选取模式: 鼠标左键框选地形"
		Mode.MOVE:
			label_status.text = "移动模式: 鼠标左键点击放置地形 (右键取消)"
	
	# Update button visual state (optional: modulate or theme)
	btn_interact.release_focus()
	btn_select.release_focus()
	btn_move.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			current_mode = Mode.INTERACT
		elif event.keycode == KEY_2:
			current_mode = Mode.SELECT
		elif event.keycode == KEY_3:
			current_mode = Mode.MOVE

	if current_mode == Mode.INTERACT:
		return

	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))

		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_mode == Mode.SELECT:
				if event.pressed:
					is_selecting = true
					selection_start = map_pos
					selection_end = map_pos
				else:
					is_selecting = false
					_capture_selection()
			
			elif current_mode == Mode.MOVE:
				if event.pressed:
					_paste_selection(map_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel or switch back to INTERACT
			current_mode = Mode.INTERACT

	elif event is InputEventMouseMotion and is_selecting:
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))
		selection_end = map_pos
		queue_redraw()
		if overlay_layer:
			overlay_layer.queue_redraw()

func _get_selection_rect() -> Rect2i:
	var start = Vector2i(min(selection_start.x, selection_end.x), min(selection_start.y, selection_end.y))
	var end = Vector2i(max(selection_start.x, selection_end.x), max(selection_start.y, selection_end.y))
	return Rect2i(start, end - start + Vector2i.ONE)

func _map_to_world_rect(rect: Rect2i) -> Rect2:
	var top_left = terrain_layer.to_global(terrain_layer.map_to_local(rect.position))
	var bottom_right = terrain_layer.to_global(terrain_layer.map_to_local(rect.end - Vector2i.ONE))
	
	# map_to_local returns center of tile, we need top-left.
	var tile_size = terrain_layer.tile_set.tile_size
	top_left -= Vector2(tile_size) / 2.0
	bottom_right += Vector2(tile_size) / 2.0
	
	return Rect2(top_left, bottom_right - top_left)

func draw_rect_outline(rect: Rect2, color: Color, width: float):
	var points = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position
	])
	# Convert points to local space for draw_polyline
	var local_points = PackedVector2Array()
	for p in points:
		local_points.append(overlay_layer.to_local(p))
	overlay_layer.draw_polyline(local_points, color, width, true)

func _capture_selection():
	var new_rect: Rect2i = _get_selection_rect()
	var new_tiles: Array = []
	
	for x in range(new_rect.position.x, new_rect.end.x):
		for y in range(new_rect.position.y, new_rect.end.y):
			var coords: Vector2i = Vector2i(x, y)
			var source_id: int = terrain_layer.get_cell_source_id(coords)
			
			# 如果该位置没有图块，则整个选取无效
			if source_id == -1:
				copied_tiles.clear()
				tip_ui.show_tip("选取无效：必须包含完整地形")
				return
			
			var atlas_coords: Vector2i = terrain_layer.get_cell_atlas_coords(coords)
			var alternative_tile: int = terrain_layer.get_cell_alternative_tile(coords)
			
			new_tiles.append({
				"offset": coords - new_rect.position,
				"source_id": source_id,
				"atlas_coords": atlas_coords,
				"alternative_tile": alternative_tile
			})
	
	selection_rect = new_rect
	copied_tiles = new_tiles
	tip_ui.show_tip("选取成功：已捕获 " + str(copied_tiles.size()) + " 个图块")

func _can_place_at(target_pos: Vector2i) -> bool:
	if copied_tiles.is_empty():
		return false
	
	for tile in copied_tiles:
		var pos = target_pos + tile.offset
		if terrain_layer.get_cell_source_id(pos) == -1:
			return false
	return true

func _paste_selection(target_pos: Vector2i):
	if copied_tiles.is_empty():
		tip_ui.show_tip("放置失败：没有已选取的内容")
		return
	
	if not _can_place_at(target_pos):
		tip_ui.show_tip("放置失败：不在范围内")
		return

	for tile in copied_tiles:
		var pos = target_pos + tile.offset
		terrain_layer.set_cell(pos, tile.source_id, tile.atlas_coords, tile.alternative_tile)
	
	tip_ui.show_tip("放置成功")
	copied_tiles.clear()
	current_mode = Mode.INTERACT

func _process(_delta: float) -> void:
	if current_mode == Mode.MOVE:
		queue_redraw()
		if overlay_layer:
			overlay_layer.queue_redraw()
		
		if preview_layer and preview_layer.visible:
			var mouse_pos = get_global_mouse_position()
			var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))
			# Align preview layer with grid
			var world_pos = terrain_layer.to_global(terrain_layer.map_to_local(map_pos))
			preview_layer.global_position = world_pos - Vector2(terrain_layer.tile_set.tile_size) / 2.0

func _setup_preview_layer():
	if not preview_layer:
		preview_layer = TileMapLayer.new()
		add_child(preview_layer)
	
	if terrain_layer:
		preview_layer.tile_set = terrain_layer.tile_set
		
	preview_layer.modulate = Color(1, 1, 1, 1) # Slightly transparent
	preview_layer.hide()
	
	if not overlay_layer:
		overlay_layer = Node2D.new()
		add_child(overlay_layer)
		overlay_layer.draw.connect(_on_overlay_draw)

func _on_overlay_draw():
	if current_mode == Mode.SELECT:
		if is_selecting:
			var rect = _get_selection_rect()
			var outline_rect = _map_to_world_rect(rect)
			draw_rect_outline(outline_rect, Color.YELLOW, 2.0)
	
	elif current_mode == Mode.MOVE:
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))
		if copied_tiles.size() > 0:
			# Preview where it will be pasted
			var rect = selection_rect
			rect.position = map_pos
			var outline_rect = _map_to_world_rect(rect)
			
			var is_valid = _can_place_at(map_pos)
			var border_color = Color.GREEN if is_valid else Color.RED
			draw_rect_outline(outline_rect, border_color, 3.0) 

func _update_preview_layer_cells():
	preview_layer.clear()
	for tile in copied_tiles:
		preview_layer.set_cell(tile.offset, tile.source_id, tile.atlas_coords, tile.alternative_tile)
