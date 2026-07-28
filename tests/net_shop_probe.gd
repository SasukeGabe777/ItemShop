extends Node
## M10: shop online. A replicated customer's negotiation is assigned to the
## CLIENT on the shared round-robin; the client plays it out and the sale is
## applied host-side (item leaves the display, gold + summary update) and
## syncs back to everyone.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_shop_client.json"

	var failures: Array[String] = []
	var watch_updates: Array[Dictionary] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
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
		DayBriefing.last_shown_day = TimeManager.day
		InventoryManager.add_item("kh_potion", 3)
		InventoryManager.display[0] = "kh_potion"

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		Net.scene_event.connect(func(event_name: String, args: Dictionary) -> void:
			if event_name == "nego_watch_update":
				watch_updates.append(args.duplicate(true)))
		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var client_log := ProjectSettings.globalize_path("user://net_shop_client_log.txt")
		var pid := OS.create_process("cmd.exe", ["/c",
			"\"%s\" --headless --path \"%s\" res://tests/net_shop_client.tscn > \"%s\" 2>&1"
			% [exe, proj, client_log]])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		SceneRouter.go("shop")
		await get_tree().create_timer(2.0).timeout
		var shop := get_tree().current_scene
		_expect(shop != null and shop.scene_file_path.ends_with("shop.tscn"),
			"host did not reach the shop")

		# Inject a replicated customer and force the round-robin onto seat 2.
		await get_tree().create_timer(2.0).timeout  # let the client land first
		var data := {
			"id": "net_probe_cust", "name": "Net Probe", "archetype": "adventurer",
			"budget": 999999, "world": "kingdom_hearts", "named": false,
		}
		var c := ShopCustomer.new()
		shop.add_child(c)
		c.position = Vector2(300, 350)
		c.setup(data, shop.browse_points, shop.ENTRANCE)
		shop.live_customers.append(c)
		Replica.host_register(c, "customer", {"data": data, "preferred_point": [],
			"item": "", "slot": -1})
		shop.set("_net_next_slot", 2)
		shop._on_negotiate_requested(data, "kh_potion")
		_expect(shop.get("negotiating") != null, "assignment did not reserve the line")
		_expect(bool((shop.get("_net_busy") as Dictionary).get(2, false)),
			"seat 2 not flagged busy during assignment")
		_expect(int(shop.get("_net_next_slot")) == 1, "round-robin cursor did not advance")
		var watch_seen := await _wait_for(func() -> bool:
			return not watch_updates.is_empty(), 8.0)
		_expect(watch_seen, "spectator negotiation feed never reached the host")
		if watch_seen:
			_expect(int(watch_updates[-1].get("who", 0)) == 2,
				"spectator feed names the wrong negotiator")
			_expect(String(watch_updates[-1].get("item_id", "")) == "kh_potion",
				"spectator feed names the wrong item")
		_expect(shop.hud.negotiation_watch != null \
			and shop.hud.negotiation_watch.visible,
			"host HUD never opened the negotiation picture-in-picture")
		_expect(not shop.player.frozen and not bool(shop.get("busy")),
			"spectating a partner's negotiation blocked host movement")

		# The client accepts at 40g -> host applies the sale.
		var gold_before := EconomyManager.gold
		var sold := await _wait_for(func() -> bool:
			return EconomyManager.gold == gold_before + 40, 30.0)
		_expect(sold, "sale gold never landed host-side (%d)" % EconomyManager.gold)
		_expect(not ("kh_potion" in InventoryManager.displayed_ids()),
			"item never left the display")
		_expect(int((shop.get("session_summary") as Dictionary).get("sales", 0)) == 1,
			"session summary missed the sale")
		_expect(shop.get("negotiating") == null, "line never freed after the result")
		_expect(not bool((shop.get("_net_busy") as Dictionary).get(2, true)),
			"seat 2 still flagged busy")
		_expect(not shop.hud.negotiation_watch.visible,
			"spectator picture-in-picture stayed open after the deal")

		var reported := await _wait_for(func() -> bool:
			return FileAccess.file_exists(REPORT_PATH), 25.0)
		_expect(reported, "client never wrote its report")
		await get_tree().create_timer(0.5).timeout
		if reported:
			var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f = null
			var report: Dictionary = parsed if parsed is Dictionary else {}
			_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
			_expect(bool(report.get("customer_seen", false)), "client never saw the customer puppet")
			_expect(bool(report.get("panel_seen", false)), "client never got the panel")
			_expect(int(report.get("gold_after", -1)) == EconomyManager.gold,
				"client gold diverged: %s vs %d" % [report.get("gold_after"), EconomyManager.gold])

		Net.leave()
		if failures.is_empty():
			print("NET_SHOP_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_SHOP_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
