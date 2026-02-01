class_name TipUI
extends PanelContainer

@onready var _label: Label = %"Label"

var _current_tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	hide()


## 显示提示信息并在指定时间后使用 Tween 动画自动隐藏
func show_tip(text: String, duration: float = 1.0) -> void:
	if _current_tween:
		_current_tween.kill()
	
	_label.text = text
	self.show()
	
	_current_tween = create_tween()
	# 淡入
	_current_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	# 持续时间
	_current_tween.tween_interval(duration)
	# 淡出
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	# 动画完成后隐藏
	_current_tween.tween_callback(self.hide)
