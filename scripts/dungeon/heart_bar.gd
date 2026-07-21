extends Range
class_name HeartBar
## HP display drawn as a row of game-authentic heart icons (e.g. Minish Cap
## hearts in the Hyrule dungeon). Drop-in for the plain _hud_bar Range: value/
## max_value drive it, HP_PER_HEART hp per heart, half-heart precision when
## half art exists. Textures are captured HUD art wired via worlds.json
## ("hud": {"hp_style": "hearts", "heart_full": ..., "heart_half": ...,
## "heart_empty": ...}).

const HP_PER_HEART := 20.0

var tex_full: Texture2D
var tex_half: Texture2D
var tex_empty: Texture2D


func setup(full: Texture2D, half: Texture2D, empty: Texture2D) -> void:
	tex_full = full
	tex_half = half
	tex_empty = empty
	value_changed.connect(func(_v: float) -> void: queue_redraw())
	changed.connect(queue_redraw)
	_update_min_size()


func _update_min_size() -> void:
	if tex_full == null:
		return
	var n := int(ceil(max_value / HP_PER_HEART))
	custom_minimum_size = Vector2(n * (tex_full.get_width() + 2), tex_full.get_height() + 2)


func _draw() -> void:
	if tex_full == null:
		return
	_update_min_size()
	var n := int(ceil(max_value / HP_PER_HEART))
	var y := (size.y - tex_full.get_height()) / 2.0
	for i in n:
		var heart_hp := value - i * HP_PER_HEART
		var tex := tex_empty
		if heart_hp >= HP_PER_HEART * 0.75 or (tex_half == null and heart_hp >= HP_PER_HEART * 0.5):
			tex = tex_full
		elif tex_half != null and heart_hp >= HP_PER_HEART * 0.25:
			tex = tex_half
		if tex != null:
			draw_texture(tex, Vector2(i * (tex_full.get_width() + 2), y))
