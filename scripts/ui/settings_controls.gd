class_name GameSettingsControls
extends RefCounted
## Shared pause-menu settings. The sliders write through AudioManager so the
## mix changes live and persists across launches; UI size keeps using the
## existing split-screen presets and takes effect when the next menu opens.


static func open(parent: Node, on_back: Callable) -> void:
	var parts := UIKit.modal(parent, "Audio & Display")
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	layer.process_mode = Net.pause_layer_mode()
	add_to(box)
	box.add_child(UIKit.button("Back", func() -> void:
		layer.queue_free()
		if on_back.is_valid():
			on_back.call()))


static func add_to(parent: VBoxContainer) -> void:
	_add_volume(parent, "Master", AudioManager.master_level,
		AudioManager.set_master_level)
	_add_volume(parent, "Music", AudioManager.music_level,
		AudioManager.set_music_level)
	_add_volume(parent, "Sound effects", AudioManager.sfx_level,
		AudioManager.set_sfx_level)
	var size_button := UIKit.button(
		"UI size: %s" % MultiplayerState.ui_scale_label(), Callable(), 10)
	size_button.pressed.connect(func() -> void:
		MultiplayerState.cycle_ui_scale()
		size_button.text = "UI size: %s" % MultiplayerState.ui_scale_label())
	parent.add_child(size_button)
	parent.add_child(UIKit.label(
		"UI size applies when the next menu opens.", 8, UIKit.COL_DIM))


static func _add_volume(parent: VBoxContainer, title: String,
		initial: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := UIKit.label(title, 9, UIKit.COL_INK)
	label.custom_minimum_size.x = 92
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "%sVolume" % title.replace(" ", "")
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = round(initial * 100.0)
	slider.custom_minimum_size = Vector2(180, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := UIKit.label("%d%%" % int(slider.value), 9, UIKit.COL_DIM)
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
		setter.call(value / 100.0))
