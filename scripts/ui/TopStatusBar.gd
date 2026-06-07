class_name TopStatusBar
extends Control

var button_row: HBoxContainer
var coin_popup_label: Label
var level_button: Button
var coin_button: Button
var rent_button: Button
var pending_auto_income := 0
var coin_popup_timer := 0.0

func _ready() -> void:
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
	level_button.text = "Lv.%d" % GameState.apartment_level
	coin_button.text = str(GameState.coins)
	rent_button.text = "%.1f/m" % GameState.total_rent_per_minute

func _build_nodes() -> void:
	button_row = get_node_or_null("ButtonRow") as HBoxContainer
	if button_row == null:
		push_error("TopStatusBar scene is missing ButtonRow.")
		return
	level_button = button_row.get_node_or_null("LevelButton") as Button
	coin_button = button_row.get_node_or_null("CoinButton") as Button
	rent_button = button_row.get_node_or_null("RentButton") as Button
	if level_button == null or coin_button == null or rent_button == null:
		push_error("TopStatusBar scene is missing LevelButton, CoinButton, or RentButton.")
		return
	_connect_button_once(level_button, UIManager.open_apartment_overview)
	_connect_button_once(coin_button, UIManager.open_income_detail)
	_connect_button_once(rent_button, UIManager.open_rent_detail)

	coin_popup_label = get_node_or_null("CoinGainPopup") as Label
	if coin_popup_label == null:
		push_error("TopStatusBar scene is missing CoinGainPopup.")
		return
	coin_popup_label.visible = false

func _connect_events() -> void:
	if not GameEvents.coins_changed.is_connected(_on_coins_changed):
		GameEvents.coins_changed.connect(_on_coins_changed)
	if not GameEvents.rent_changed.is_connected(_on_rent_changed):
		GameEvents.rent_changed.connect(_on_rent_changed)
	if not GameEvents.apartment_level_changed.is_connected(_on_apartment_level_changed):
		GameEvents.apartment_level_changed.connect(_on_apartment_level_changed)
	if not GameEvents.coin_gain_recorded.is_connected(_on_coin_gain_recorded):
		GameEvents.coin_gain_recorded.connect(_on_coin_gain_recorded)

func _connect_button_once(button: Button, callback: Callable) -> void:
	if button != null and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _on_coins_changed(_value: int) -> void:
	refresh_from_state()

func _on_rent_changed(_value: float) -> void:
	refresh_from_state()

func _on_apartment_level_changed(_level: int) -> void:
	refresh_from_state()

func _on_coin_gain_recorded(amount: int, source: String) -> void:
	if source == "auto_income":
		pending_auto_income += amount
