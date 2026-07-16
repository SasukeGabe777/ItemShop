@tool
extends VBoxContainer
## Validation tab: runs CCSValidator and renders ERROR/WARNING/INFO rows.
## Read-only — fixing a finding always happens in the Asset Assignment,
## Asset Browser, or UI Assets tab (or by hand in data/*.json).

signal run_requested

const SEVERITY_COLOR := {
	"ERROR": Color(1.0, 0.45, 0.45),
	"WARNING": Color(1.0, 0.8, 0.4),
	"INFO": Color(0.6, 0.8, 1.0),
}

var _tree: Tree
var _summary_label: Label
var _filter_option: OptionButton
var _all_results: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var top := HBoxContainer.new()
	var run_btn := Button.new()
	run_btn.text = "Run Validation"
	run_btn.pressed.connect(run_requested.emit)
	top.add_child(run_btn)
	top.add_child(_label("Filter:"))
	_filter_option = OptionButton.new()
	for s in ["All", "ERROR", "WARNING", "INFO"]:
		_filter_option.add_item(s)
	_filter_option.item_selected.connect(func(_i): _render())
	top.add_child(_filter_option)
	add_child(top)

	_summary_label = _label("Run validation to see results.")
	add_child(_summary_label)
	add_child(HSeparator.new())

	_tree = Tree.new()
	_tree.columns = 5
	_tree.set_column_title(0, "Severity")
	_tree.set_column_title(1, "Type")
	_tree.set_column_title(2, "ID")
	_tree.set_column_title(3, "Message")
	_tree.set_column_title(4, "Expected Path")
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.set_column_expand(3, true)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tree)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func set_results(results: Array[Dictionary]) -> void:
	_all_results = results
	_render()


func _render() -> void:
	_tree.clear()
	var filter := "All"
	if _filter_option.selected >= 0:
		filter = _filter_option.get_item_text(_filter_option.selected)
	var root := _tree.create_item()
	var counts := {"ERROR": 0, "WARNING": 0, "INFO": 0}
	for row in _all_results:
		var sev := String(row.get("severity", "INFO"))
		counts[sev] = int(counts.get(sev, 0)) + 1
		if filter != "All" and sev != filter:
			continue
		var item := _tree.create_item(root)
		item.set_text(0, sev)
		item.set_custom_color(0, SEVERITY_COLOR.get(sev, Color.WHITE))
		item.set_text(1, String(row.get("type", "")))
		item.set_text(2, String(row.get("id", "")))
		item.set_text(3, String(row.get("message", "")))
		item.set_text(4, String(row.get("path", "")))
	_summary_label.text = "%d error(s), %d warning(s), %d info — %d total" % [
		counts["ERROR"], counts["WARNING"], counts["INFO"], _all_results.size()]
