@tool
extends TabContainer
## Root control for the Crossroads Asset Factory dock: owns the single
## content scan / credits index / validation pass and hands them to each tab.
## Factory tabs (Items, Heroes, Customers, Enemies, Locations, Shop Furniture)
## write content; the classic tabs (Asset Browser/Assignment, UI Assets) stay
## read-mostly, and Validation covers everything.

const DashboardTab := preload("res://addons/crossroads_content_studio/ui/dashboard_tab.gd")
const ImportQueueTab := preload("res://addons/crossroads_content_studio/ui/import_queue_tab.gd")
const ItemsTab := preload("res://addons/crossroads_content_studio/ui/items_tab.gd")
const HeroesTab := preload("res://addons/crossroads_content_studio/ui/heroes_tab.gd")
const CustomersTab := preload("res://addons/crossroads_content_studio/ui/customers_tab.gd")
const EnemiesTab := preload("res://addons/crossroads_content_studio/ui/enemies_tab.gd")
const LocationsTab := preload("res://addons/crossroads_content_studio/ui/location_workshop_tab.gd")
const FurnitureTab := preload("res://addons/crossroads_content_studio/ui/furniture_tab.gd")
const AssetBrowserTab := preload("res://addons/crossroads_content_studio/ui/asset_browser_tab.gd")
const AssetAssignmentTab := preload("res://addons/crossroads_content_studio/ui/asset_assignment_tab.gd")
const UiAssetsTab := preload("res://addons/crossroads_content_studio/ui/ui_assets_tab.gd")
const ValidationTab := preload("res://addons/crossroads_content_studio/ui/validation_tab.gd")

var scan := CCSContentScan.new()
var credits := CCSCreditsIndex.new()
var results: Array[Dictionary] = []

var dashboard
var import_queue
var items_tab
var heroes_tab
var customers_tab
var enemies_tab
var locations_tab
var furniture_tab
var browser
var assignment
var ui_assets
var validation


func _ready() -> void:
	tabs_visible = true

	dashboard = DashboardTab.new()
	dashboard.name = "Dashboard"
	add_child(dashboard)

	import_queue = ImportQueueTab.new()
	import_queue.name = "Import Queue"
	add_child(import_queue)

	items_tab = ItemsTab.new()
	items_tab.name = "Items"
	add_child(items_tab)

	heroes_tab = HeroesTab.new()
	heroes_tab.name = "Heroes"
	add_child(heroes_tab)

	customers_tab = CustomersTab.new()
	customers_tab.name = "Customers"
	add_child(customers_tab)

	enemies_tab = EnemiesTab.new()
	enemies_tab.name = "Enemies"
	add_child(enemies_tab)

	locations_tab = LocationsTab.new()
	locations_tab.name = "Location Workshop"
	add_child(locations_tab)

	furniture_tab = FurnitureTab.new()
	furniture_tab.name = "Shop Furniture"
	add_child(furniture_tab)

	browser = AssetBrowserTab.new()
	browser.name = "Asset Browser"
	add_child(browser)

	assignment = AssetAssignmentTab.new()
	assignment.name = "Asset Assignment"
	add_child(assignment)

	ui_assets = UiAssetsTab.new()
	ui_assets.name = "UI Assets"
	add_child(ui_assets)

	validation = ValidationTab.new()
	validation.name = "Validation"
	add_child(validation)

	dashboard.reload_requested.connect(reload_all)
	dashboard.validate_requested.connect(_on_validate_requested)
	validation.run_requested.connect(reload_all)
	for writer in [import_queue, items_tab, heroes_tab, customers_tab, enemies_tab, locations_tab, furniture_tab]:
		writer.data_written.connect(reload_all)

	reload_all()


func reload_all() -> void:
	scan.scan()
	credits.build()
	results = CCSValidator.run(scan)
	dashboard.refresh(scan, results)
	import_queue.setup(scan)
	items_tab.setup(scan)
	heroes_tab.setup(scan)
	customers_tab.setup(scan)
	enemies_tab.setup(scan)
	locations_tab.setup(scan)
	furniture_tab.setup(scan)
	browser.setup(credits, _referenced_world_ids())
	assignment.setup(scan)
	ui_assets.setup()
	validation.set_results(results)


func _on_validate_requested() -> void:
	reload_all()
	current_tab = get_tab_idx_from_control(validation)


func _referenced_world_ids() -> Array[String]:
	var ids: Dictionary = {}
	var sources := [scan.items_raw, scan.heroes_raw, scan.npcs_raw, scan.enemies_raw, scan.bosses_raw]
	for raw in sources:
		for entry: Dictionary in raw:
			var world := String(entry.get("world", ""))
			if world != "":
				ids[world] = true
	for w: String in scan.world_order:
		ids[w] = true
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	return out
