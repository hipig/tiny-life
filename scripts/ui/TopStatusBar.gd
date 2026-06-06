class_name TopStatusBar
extends Control

var button_row: HBoxContainer
var coin_popup_label: Label
var pending_auto_income := 0
var coin_popup_timer := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 70)
	_build_nodes()
	_connect_events()
	refresh_from_state()

func _process(delta: float) -> void:
	coin_popup_timer += delta
	var interval := float(ConfigManager.get_economy_value("coin_popup_interval", 6.0))
	if coin_popup_timer < interval:
		return
	coin_popup_timer = 0.0
	if pending_auto_income <= 0:
		return
	coin_popup_label.text = "+%d" % pending_auto_income
	coin_popup_label.visible = true
	pending_auto_income = 0
	await get_tree().create_timer(1.3).timeout
	if is_instance_valid(coin_popup_label):
		coin_popup_label.visible = false

func refresh_from_state() -> void:
	if button_row == null:
		return
	UIPanelFactory.clear_children(button_row)
	var level_button := _status_button("公寓 Lv.%d" % GameState.apartment_level)
	level_button.pressed.connect(UIManager.open_apartment_overview)
	button_row.add_child(level_button)

	var coin_button := _status_button("金币 %d" % GameState.coins)
	coin_button.pressed.connect(UIManager.open_income_detail)
	button_row.add_child(coin_button)

	var rent_button := _status_button("租金 %.1f/分钟" % GameState.total_rent_per_minute)
	rent_button.pressed.connect(UIManager.open_rent_detail)
	button_row.add_child(rent_button)

func _build_nodes() -> void:
	button_row = get_node_or_null("ButtonRow") as HBoxContainer
	if button_row == null:
		button_row = HBoxContainer.new()
		button_row.name = "ButtonRow"
		button_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(button_row)
	button_row.add_theme_constant_override("separation", 8)

	coin_popup_label = get_node_or_null("CoinGainPopup") as Label
	if coin_popup_label == null:
		coin_popup_label = Label.new()
		coin_popup_label.name = "CoinGainPopup"
		coin_popup_label.position = Vector2(310, 48)
		add_child(coin_popup_label)
	coin_popup_label.visible = false
	coin_popup_label.add_theme_font_size_override("font_size", 30)
	coin_popup_label.add_theme_color_override("font_color", Color("#2b9348"))

func _connect_events() -> void:
	if not GameEvents.coins_changed.is_connected(_on_coins_changed):
		GameEvents.coins_changed.connect(_on_coins_changed)
	if not GameEvents.rent_changed.is_connected(_on_rent_changed):
		GameEvents.rent_changed.connect(_on_rent_changed)
	if not GameEvents.apartment_level_changed.is_connected(_on_apartment_level_changed):
		GameEvents.apartment_level_changed.connect(_on_apartment_level_changed)
	if not GameEvents.coin_gain_recorded.is_connected(_on_coin_gain_recorded):
		GameEvents.coin_gain_recorded.connect(_on_coin_gain_recorded)

func _status_button(text: String) -> Button:
	var button := Button.new()
	UIPanelFactory.style_button(button)
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _on_coins_changed(_value: int) -> void:
	refresh_from_state()

func _on_rent_changed(_value: float) -> void:
	refresh_from_state()

func _on_apartment_level_changed(_level: int) -> void:
	refresh_from_state()

func _on_coin_gain_recorded(amount: int, source: String) -> void:
	if source == "auto_income":
		pending_auto_income += amount
