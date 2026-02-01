extends Control

## 取景器形状预览 UI
## 显示当前可用的形状列表以及它们缓存的内容

@export var viewfinder_system: ViewfinderSystem
@onready var container: VBoxContainer = %VBoxContainer

func _ready() -> void:
	if not viewfinder_system:
		# 尝试从场景中找
		viewfinder_system = get_tree().get_first_node_in_group("viewfinder_system")
		if not viewfinder_system:
			# 如果还没找到，等之后手动赋值
			pass
	
	if viewfinder_system:
		viewfinder_system.shapes_changed.connect(refresh)
		refresh()

## 刷新整个列表
func refresh() -> void:
	# 清空现有子节点
	for child in container.get_children():
		child.queue_free()
	
	if not viewfinder_system:
		return
	
	var active_resources = viewfinder_system.active_shape_resources
	var caches = viewfinder_system.active_shape_caches
	var current_idx = viewfinder_system.active_shape_index
	
	for i in range(active_resources.size()):
		var shape_res = active_resources[i]
		var cache = caches[i]
		var is_selected = (i == current_idx)
		
		var item_ui = _create_item_ui(shape_res, cache, is_selected)
		container.add_child(item_ui)

func _create_item_ui(shape_res: SelectorShape, cache: Variant, is_selected: bool) -> Control:
	var panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	if is_selected:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		style.border_width_right = 4
		style.border_color = Color.GOLD
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 12)
	margin.add_child(hbox)
	
	# 形状图形预览
	var preview_rect = Control.new()
	preview_rect.custom_minimum_size = Vector2(40, 40)
	preview_rect.draw.connect(func(): _draw_shape_preview(preview_rect, shape_res.cells, cache))
	hbox.add_child(preview_rect)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# 形状名称
	var label = Label.new()
	label.text = shape_res.shape_name
	label.add_theme_font_size_override("font_size", 14)
	if is_selected:
		label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(label)
	
	# 状态/内容描述
	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	if cache:
		status_label.text = "已记录地形"
		status_label.add_theme_color_override("font_color", Color.SPRING_GREEN)
	else:
		status_label.text = "待选取"
		status_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(status_label)
	
	return panel

func _draw_shape_preview(canvas: Control, cells: Array[Vector2i], cache: Variant) -> void:
	if cells.is_empty():
		return
		
	# 计算包围盒以便居中显示
	var min_v = cells[0]
	var max_v = cells[0]
	for c in cells:
		min_v.x = min(min_v.x, c.x)
		min_v.y = min(min_v.y, c.y)
		max_v.x = max(max_v.x, c.x)
		max_v.y = max(max_v.y, c.y)
	
	var size = max_v - min_v + Vector2i.ONE
	var cell_size = min(canvas.size.x / size.x, canvas.size.y / size.y) * 0.8
	var offset = (canvas.size - Vector2(size) * cell_size) / 2.0
	
	# 获取图集
	var tile_set: TileSet = null
	if viewfinder_system and viewfinder_system.terrain_layer:
		tile_set = viewfinder_system.terrain_layer.tile_set
	
	# 将缓存的内容转为 Map 方便查找
	var cached_tiles_map = {}
	if cache and cache.has("tiles"):
		for t in cache["tiles"]:
			cached_tiles_map[t["offset"]] = t

	for c in cells:
		var rect = Rect2(offset + Vector2(c - min_v) * cell_size, Vector2(cell_size, cell_size))
		
		var tile_info = cached_tiles_map.get(c)
		if tile_info and tile_set:
			# 如果有缓存内容，绘制实际贴图
			var source_id = tile_info["source_id"]
			var atlas_coords = tile_info["atlas_coords"]
			var modulate = tile_info.get("modulate", Color.WHITE)
			
			var source = tile_set.get_source(source_id)
			if source is TileSetAtlasSource:
				var tex = source.texture
				var region = source.get_tile_texture_region(atlas_coords)
				canvas.draw_texture_rect_region(tex, rect, region, modulate)
			else:
				# 回退方案
				canvas.draw_rect(rect.grow(-1), modulate)
		else:
			# 没填充内容时显示半透明蓝色底（示意）
			canvas.draw_rect(rect.grow(-1), Color(0.3, 0.5, 0.8, 0.4))
		
		# 始终绘制细线边框以区分格子
		canvas.draw_rect(rect.grow(-1), Color(1, 1, 1, 0.2), false, 1.0)
