extends Node
## M0 foundation guard: the Net/PartyState/Replica autoloads must exist and be
## completely inert offline — couch co-op, saves and scene routing behave
## exactly as before them.


class Probe:
	extends Node

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		_reset_state()

		# 1. Offline predicates: nothing networked, this machine is authority.
		_expect(not Net.is_online(), "Net thinks it is online at boot")
		_expect(not Net.is_host() and not Net.is_client(), "Net has a role at boot")
		_expect(Net.is_authority(), "offline machine is not authority")
		_expect(PartyState.mode == PartyState.Mode.SINGLE, "boot mode is not SINGLE")
		_expect(PartyState.local_index() == 1, "local index is not 1")
		_expect(PartyState.count() == 1, "single mode has %d seats" % PartyState.count())

		# 2. Command bus runs locally offline, callback and all.
		var before := EconomyManager.gold
		Net.request("economy.add_gold", {"amount": 120})
		_expect(EconomyManager.gold == before + 120, "offline add_gold did not apply")
		var spend_ok := [true]
		Net.request("economy.spend_gold", {"amount": EconomyManager.gold + 999},
			func(ok: bool, _data: Dictionary) -> void: spend_ok[0] = ok)
		_expect(not spend_ok[0], "overdraft spend_gold reported ok")
		var placed := [false]
		InventoryManager.add_item("kh_potion", 1)
		Net.request("inventory.place_display", {"slot": 0, "item_id": "kh_potion"},
			func(ok: bool, _data: Dictionary) -> void: placed[0] = ok)
		_expect(placed[0] and String(InventoryManager.display[0]) == "kh_potion",
			"offline place_display did not apply")

		# 3. Save snapshot round-trip through the new public wrappers.
		var snap := SaveManager.snapshot()
		var gold_at_snap := EconomyManager.gold
		var potions_at_snap := InventoryManager.count("kh_potion")
		EconomyManager.add_gold(55)
		InventoryManager.add_item("kh_potion", 3)
		_expect(snap.get("inventory", {}).get("storage", {}).get("kh_potion", 0) == potions_at_snap,
			"snapshot shares live references (mutation leaked into it)")
		SaveManager.apply_snapshot(snap)
		_expect(EconomyManager.gold == gold_at_snap, "snapshot restore missed gold")
		_expect(InventoryManager.count("kh_potion") == potions_at_snap,
			"snapshot restore missed storage")

		# 4. Couch co-op is untouched and mirrors into PartyState.
		MultiplayerState.set_enabled(true)
		_expect(MultiplayerState.enabled, "couch enable failed")
		_expect(InputMap.has_action("p2_attack"), "couch input split missing p2_attack")
		_expect(PartyState.mode == PartyState.Mode.COUCH, "couch mode not mirrored")
		_expect(PartyState.count() == 2, "couch roster is not 2 seats")
		_expect(not PartyState.ready_up("open_shop", 1), "couch ready gate passed with 1/2")
		_expect(PartyState.ready_up("open_shop", 2), "couch ready gate failed at 2/2")
		MultiplayerState.set_enabled(false)
		_expect(not InputMap.has_action("p2_attack"), "couch disable left p2 actions")
		_expect(PartyState.mode == PartyState.Mode.SINGLE, "couch off did not restore SINGLE")

		# 5. Ready facade trivially passes solo.
		_expect(PartyState.ready_up("anything", 1), "solo ready gate blocked")

		# 6. Scene routing still works offline and stamps Replica generations.
		var gen_before := Replica.gen
		SceneRouter.go("town")
		await get_tree().create_timer(1.2).timeout
		var scene := get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("town.tscn"),
			"offline SceneRouter.go(town) did not land in town")
		_expect(Replica.gen == gen_before + 1, "Replica generation did not advance with go()")

		if failures.is_empty():
			print("NET_OFFLINE_REGRESSION_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_OFFLINE_REGRESSION_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _reset_state() -> void:
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
