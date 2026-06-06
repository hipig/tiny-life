extends Control

@onready var color_fallback: ColorRect = $ColorFallback
@onready var avatar_sprite: AnimatedSprite2D = $AvatarSprite
@onready var need_bubble: NeedBubble = $NeedBubble
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var tenant_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(40, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not tenant_id.is_empty():
		_refresh()

func setup(id: String) -> void:
	tenant_id = id
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	var asset: Dictionary = data.get("asset", {})
	color_fallback.color = AssetResolver.color_from_asset(asset, Color("#5ca6ff"))
	AssetResolver.apply_asset_to_animated_sprite(avatar_sprite, asset, "idle", Color("#5ca6ff"), Vector2i(28, 36))
	need_bubble.show_behavior(str(state.get("current_behavior", "")))
	if animation_player.has_animation("idle"):
		animation_player.play("idle")
