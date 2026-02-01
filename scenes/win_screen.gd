extends CanvasLayer

@onready var btn_back_to_menu: Button = %BtnBackToMenu

func _ready() -> void:
	btn_back_to_menu.pressed.connect(_on_btn_back_to_menu_pressed)

func _on_btn_back_to_menu_pressed() -> void:
	GameManager.back_to_menu()
