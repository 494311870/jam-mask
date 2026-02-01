class_name ViewfinderSystem
extends Node2D

enum Mode { INTERACT, SELECT, MOVE }

@export var terrain_layer: TileMapLayer
@export var elements_layer: TileMapLayer

@export_group("Visuals")
@export var color_pasted: Color = Color.YELLOW
@export var color_select: Color = Color.YELLOW
@export var color_valid: Color = Color.GREEN
@export var color_invalid: Color = Color.RED
@export var outline_width: float = 2.0
@export var outline_width_active: float = 2.5

var current_mode: Mode = Mode.INTERACT:
	set(value):
		current_mode = value
		_on_mode_changed()

var active_shapes: Array[Array] = []
var active_shape_index: int = 0:
	set(value):
		active_shape_index = value
		shapes_changed.emit()

# Array of TileDataInfo or similar
var copied_tiles: Array = []
var selection_rect: Rect2i
var preview_layer: TileMapLayer
var overlay_layer: Node2D

## 记录已粘贴的形状（绝对坐标数组）
var pasted_shapes: Array[Array] = []
## 记录已被粘贴内容占据的格子坐标，用于快速查找 (Vector2i -> bool)
var occupied_cells: Dictionary = {}
## 缓存每个形状对应的已取景内容 (与 active_shapes 索引一一对应)
var active_shape_caches: Array = []

## 新增：记录当前可用的 SelectorShape 资源，用于 UI 显示
var active_shape_resources: Array[SelectorShape] = []

signal shapes_changed

@onready var btn_interact: Button = %BtnInteract
@onready var btn_select: Button = %BtnSelect
@onready var btn_move: Button = %BtnMove
@onready var label_status: Label = %LabelStatus
@onready var tip_ui: TipUI = %TipUI
@onready var ui_container: Control = $ViewfinderUI/Control

func _ready() -> void:
	if terrain_layer or elements_layer:
		setup_layers(terrain_layer, elements_layer)
	
	btn_interact.pressed.connect(func(): current_mode = Mode.INTERACT)
	btn_select.pressed.connect(func(): current_mode = Mode.SELECT)
	btn_move.pressed.connect(func(): current_mode = Mode.MOVE)

## 设置当前操作的地图层
func setup_layers(terrain: TileMapLayer, elements: TileMapLayer, shapes: Array[SelectorShape] = []) -> void:
	terrain_layer = terrain
	elements_layer = elements
	
	pasted_shapes.clear()
	occupied_cells.clear()
	active_shape_caches.clear()
	active_shape_resources.clear()
	active_shapes = []
	
	if not shapes.is_empty():
		active_shape_resources = shapes.duplicate()
		for s in shapes:
			active_shapes.append(s.cells)
	
	if ui_container:
		ui_container.visible = not active_shapes.is_empty()
	
	active_shape_caches.resize(active_shapes.size())
	active_shape_caches.fill(null)
	
	active_shape_index = 0
	
	if terrain_layer:
		_setup_preview_layer()
	
	current_mode = Mode.INTERACT
	shapes_changed.emit()

func _on_mode_changed():
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
			label_status.text = "(Q/E) 选择取景器"
		Mode.SELECT:
			if active_shapes.is_empty():
				label_status.text = "已无可用的取景器"
			else:
				label_status.text = "(鼠标) 移动取景器    (左键) 记录地形    (Q/E) 切换取景器"
		Mode.MOVE:
			label_status.text = "(左键) 放置地形    (右键) 重新选择地形"
	
	# Update button visual state (optional: modulate or theme)
	btn_interact.release_focus()
	btn_select.release_focus()
	btn_move.release_focus()
	
	btn_select.disabled = active_shapes.is_empty()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q or event.keycode == KEY_E:
			if active_shapes.is_empty():
				tip_ui.show_tip("选取失败：已无可用形状")
				return
			
			# 保存当前索引的缓存
			if current_mode == Mode.MOVE and not copied_tiles.is_empty():
				active_shape_caches[active_shape_index] = {
					"tiles": copied_tiles.duplicate(true),
					"rect": selection_rect
				}
			elif current_mode == Mode.SELECT:
				active_shape_caches[active_shape_index] = null

			if event.keycode == KEY_Q:
				active_shape_index = (active_shape_index - 1 + active_shapes.size()) % active_shapes.size()
			else:
				active_shape_index = (active_shape_index + 1) % active_shapes.size()
			
			# 加载新索引的缓存
			var cache = active_shape_caches[active_shape_index]
			if cache:
				copied_tiles = cache["tiles"].duplicate(true)
				selection_rect = cache["rect"]
				current_mode = Mode.MOVE
			else:
				copied_tiles = []
				current_mode = Mode.SELECT
				
			_on_mode_changed()
			_update_overlay()
			shapes_changed.emit()

	if current_mode == Mode.INTERACT:
		return

	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_mode == Mode.SELECT:
				if active_shapes.is_empty():
					tip_ui.show_tip("无可用取景器")
					return
				var current_shape: Array = active_shapes[active_shape_index]
				_capture_selection(map_pos, current_shape)
			
			elif current_mode == Mode.MOVE:
				_paste_selection(map_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if current_mode == Mode.MOVE:
				copied_tiles.clear()
				active_shape_caches[active_shape_index] = null
				current_mode = Mode.SELECT
				tip_ui.show_tip("已取消选择内容")
				shapes_changed.emit()
			elif current_mode == Mode.SELECT:
				current_mode = Mode.INTERACT

	elif event is InputEventMouseMotion:
		_update_overlay()

func _update_overlay():
	queue_redraw()
	if overlay_layer:
		overlay_layer.queue_redraw()

func _map_to_world_rect(rect: Rect2i) -> Rect2:
	var top_left = terrain_layer.to_global(terrain_layer.map_to_local(rect.position))
	var bottom_right = terrain_layer.to_global(terrain_layer.map_to_local(rect.end - Vector2i.ONE))
	
	# map_to_local returns center of tile, we need top-left.
	var tile_size = terrain_layer.tile_set.tile_size
	top_left -= Vector2(tile_size) / 2.0
	bottom_right += Vector2(tile_size) / 2.0
	
	return Rect2(top_left, bottom_right - top_left)

func _draw_shape_outline(center_map_pos: Vector2i, offsets: Array, color: Color, width: float):
	var shape_set = {}
	for o in offsets:
		shape_set[o] = true
	
	for o in offsets:
		var cell_pos = center_map_pos + o
		var rect = _map_to_world_rect(Rect2i(cell_pos, Vector2i.ONE))
		
		# 检查四个方向，如果没有邻居，则绘制该方向的线条
		# Top
		if not shape_set.has(o + Vector2i(0, -1)):
			_draw_overlay_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), color, width)
		# Bottom
		if not shape_set.has(o + Vector2i(0, 1)):
			_draw_overlay_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), color, width)
		# Left
		if not shape_set.has(o + Vector2i(-1, 0)):
			_draw_overlay_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y), color, width)
		# Right
		if not shape_set.has(o + Vector2i(1, 0)):
			_draw_overlay_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), color, width)

func _draw_overlay_line(from: Vector2, to: Vector2, color: Color, width: float):
	overlay_layer.draw_line(overlay_layer.to_local(from), overlay_layer.to_local(to), color, width, true)

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

func _capture_selection(center_map_pos: Vector2i, shape: Array) -> void:
	var offsets = shape
	var new_tiles: Array = []
	
	var min_p = Vector2i(999, 999)
	var max_p = Vector2i(-999, -999)
	
	for offset in offsets:
		var coords: Vector2i = center_map_pos + offset
		var source_id: int = terrain_layer.get_cell_source_id(coords)
		
		# 如果该形状覆盖的任一位置没有图块，或者是已粘贴的内容，则整个选取无效
		if source_id == -1:
			copied_tiles.clear()
			tip_ui.show_tip("选取无效：必须在该形状覆盖的所有位置都有地形")
			return
		
		if occupied_cells.has(coords):
			copied_tiles.clear()
			tip_ui.show_tip("选取无效：不能二次取景")
			return
		
		min_p.x = min(min_p.x, offset.x)
		min_p.y = min(min_p.y, offset.y)
		max_p.x = max(max_p.x, offset.x)
		max_p.y = max(max_p.y, offset.y)
		
		var atlas_coords: Vector2i = terrain_layer.get_cell_atlas_coords(coords)
		var alternative_tile: int = terrain_layer.get_cell_alternative_tile(coords)
		var tile_data: TileData = terrain_layer.get_cell_tile_data(coords)
		var modulate: Color = Color.WHITE
		if tile_data:
			modulate = tile_data.modulate
		
		new_tiles.append({
			"offset": offset,
			"source_id": source_id,
			"atlas_coords": atlas_coords,
			"alternative_tile": alternative_tile,
			"modulate": modulate
		})
	
	selection_rect = Rect2i(min_p, max_p - min_p + Vector2i.ONE)
	copied_tiles = new_tiles
	
	# 更新缓存
	active_shape_caches[active_shape_index] = {
		"tiles": copied_tiles.duplicate(true),
		"rect": selection_rect
	}
	
	tip_ui.show_tip("选取成功：已捕获 " + str(copied_tiles.size()) + " 个图块")
	current_mode = Mode.MOVE
	shapes_changed.emit()

func _can_place_at(target_pos: Vector2i) -> bool:
	if copied_tiles.is_empty():
		return false
	
	var player = get_tree().get_first_node_in_group("player")
	var player_map_pos = Vector2i(-999, -999)
	if player:
		player_map_pos = terrain_layer.local_to_map(terrain_layer.to_local(player.global_position))
	
	for tile in copied_tiles:
		var pos = target_pos + tile.offset
		if terrain_layer.get_cell_source_id(pos) == -1:
			return false
		if occupied_cells.has(pos):
			return false
		if pos == player_map_pos:
			return false
	return true

func _paste_selection(target_pos: Vector2i):
	if copied_tiles.is_empty():
		tip_ui.show_tip("放置失败：没有已选取的内容")
		return
	
	if not _can_place_at(target_pos):
		tip_ui.show_tip("放置失败：不在有效范围内")
		return

	var new_pasted_shape: Array[Vector2i] = []
	for tile in copied_tiles:
		var pos = target_pos + tile.offset
		terrain_layer.set_cell(pos, tile.source_id, tile.atlas_coords, tile.alternative_tile)
		new_pasted_shape.append(pos)
		occupied_cells[pos] = true
	
	pasted_shapes.append(new_pasted_shape)
	
	tip_ui.show_tip("放置成功")
	
	# 每个形状只能使用一次
	active_shapes.remove_at(active_shape_index)
	active_shape_caches.remove_at(active_shape_index)
	active_shape_resources.remove_at(active_shape_index)
	
	if not active_shapes.is_empty():
		active_shape_index = active_shape_index % active_shapes.size()
	else:
		active_shape_index = 0
		
	copied_tiles.clear()
	current_mode = Mode.INTERACT
	shapes_changed.emit()

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
	# 绘制已粘贴形状的黄色边框
	for shape in pasted_shapes:
		_draw_shape_outline(Vector2i.ZERO, shape, color_pasted, outline_width)

	if current_mode == Mode.SELECT:
		if active_shapes.is_empty():
			return
			
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))
		var offsets = active_shapes[active_shape_index]
		_draw_shape_outline(map_pos, offsets, color_select, outline_width)
	
	elif current_mode == Mode.MOVE:
		var mouse_pos = get_global_mouse_position()
		var map_pos = terrain_layer.local_to_map(terrain_layer.to_local(mouse_pos))
		if copied_tiles.size() > 0:
			var is_valid = _can_place_at(map_pos)
			var border_color = color_valid if is_valid else color_invalid
			
			var offsets = []
			for tile in copied_tiles:
				offsets.append(tile.offset)
			
			_draw_shape_outline(map_pos, offsets, border_color, outline_width_active) 

func _update_preview_layer_cells():
	preview_layer.clear()
	for tile in copied_tiles:
		preview_layer.set_cell(tile.offset, tile.source_id, tile.atlas_coords, tile.alternative_tile)
