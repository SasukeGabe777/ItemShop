extends RefCounted
## Named host-side commands for Net's command bus — the ONE way shared state
## changes online. Each entry wraps an EXISTING manager mutator (whose own
## validation is the server validation) and lists which managers to
## rebroadcast afterwards. Clients call Net.request("economy.add_gold", ...);
## offline and host calls run the same entry directly.
##
## Entry shape: {"run": Callable(sender_index, args) -> Dictionary,
##               "syncs": Array[String] of Net manager names}
## The run callable returns at least {"ok": bool}; extra keys ride back to the
## requester through Net's _cmd_result.


static func build() -> Dictionary:
	var reg: Dictionary = {}

	var economy_add_gold := func(_sender: int, args: Dictionary) -> Dictionary:
		EconomyManager.add_gold(int(args.get("amount", 0)))
		return {"ok": true}
	reg["economy.add_gold"] = {"run": economy_add_gold, "syncs": ["economy"]}

	var economy_spend_gold := func(_sender: int, args: Dictionary) -> Dictionary:
		var ok: bool = EconomyManager.spend_gold(int(args.get("amount", 0)))
		return {"ok": ok, "msg": "" if ok else "Not enough gold"}
	reg["economy.spend_gold"] = {"run": economy_spend_gold, "syncs": ["economy"]}

	var inventory_place_display := func(_sender: int, args: Dictionary) -> Dictionary:
		var ok: bool = InventoryManager.place_display(
			int(args.get("slot", -1)), String(args.get("item_id", "")))
		return {"ok": ok, "msg": "" if ok else "Item no longer available"}
	reg["inventory.place_display"] = {"run": inventory_place_display, "syncs": ["inventory"]}

	var inventory_take_display := func(_sender: int, args: Dictionary) -> Dictionary:
		InventoryManager.take_display(int(args.get("slot", -1)))
		return {"ok": true}
	reg["inventory.take_display"] = {"run": inventory_take_display, "syncs": ["inventory"]}

	# Remote shop assignments report their outcomes back to the host's shop.
	var shop_nego_result := func(sender: int, args: Dictionary) -> Dictionary:
		var shop: Node = Net.get_tree().get_first_node_in_group("shop_runtime")
		if shop == null:
			return {"ok": false}
		shop._net_nego_result(sender, int(args.get("id", 0)), args.get("outcome", {}))
		return {"ok": true}
	reg["shop.nego_result"] = {"run": shop_nego_result, "syncs": []}

	var shop_order_result := func(sender: int, args: Dictionary) -> Dictionary:
		var shop: Node = Net.get_tree().get_first_node_in_group("shop_runtime")
		if shop == null:
			return {"ok": false}
		shop._net_order_result(sender, int(args.get("id", 0)), String(args.get("result", "")))
		return {"ok": true}
	reg["shop.order_result"] = {"run": shop_order_result, "syncs": []}

	var lobby_set_ready := func(sender: int, args: Dictionary) -> Dictionary:
		if not PartyState.players.has(sender):
			return {"ok": false}
		PartyState.players[sender]["ready"] = bool(args.get("ready", false))
		Net._broadcast_roster()
		return {"ok": true}
	reg["lobby.set_ready"] = {"run": lobby_set_ready, "syncs": []}

	var party_ready_up := func(sender: int, args: Dictionary) -> Dictionary:
		var all_in: bool = PartyState.ready_up(
			String(args.get("action_id", "")), sender, int(args.get("needed", -1)))
		return {"ok": true, "all_ready": all_in}
	reg["party.ready_up"] = {"run": party_ready_up, "syncs": []}

	# Shared-action gate ("everyone at the door?"). On completion the host
	# broadcasts gate_complete — the active scene's handler performs the
	# action host-side (scene change, rest, session start); progress rides a
	# broadcast toast so the whole party sees who is waiting on whom.
	var party_gate := func(sender: int, args: Dictionary) -> Dictionary:
		var action_id := String(args.get("action_id", ""))
		var complete: bool = PartyState.ready_up(action_id, sender)
		var count: int = PartyState.ready_count(action_id)
		var needed: int = PartyState.connected_indexes().size()
		if complete:
			PartyState.clear_ready(action_id)
			Net.broadcast_scene_event("gate_complete", {"action_id": action_id})
		else:
			Net.broadcast_scene_event("gate_progress",
				{"action_id": action_id, "count": count, "needed": needed, "by": sender})
		return {"ok": true, "complete": complete, "count": count, "needed": needed}
	reg["party.gate"] = {"run": party_gate, "syncs": []}

	# One player per menu, arbitrated by the host. Claims die with the scene
	# generation and with their holder's connection.
	var menu_claim := func(sender: int, args: Dictionary) -> Dictionary:
		var key := String(args.get("key", ""))
		var claim: Dictionary = Net.menu_claims.get(key, {})
		var holder := int(claim.get("idx", 0))
		var live: bool = holder > 0 and int(claim.get("gen", -1)) == Replica.gen \
			and holder in PartyState.connected_indexes()
		if live and holder != sender:
			return {"ok": false, "holder": holder}
		Net.menu_claims[key] = {"idx": sender, "gen": Replica.gen}
		return {"ok": true}
	reg["menu.claim"] = {"run": menu_claim, "syncs": []}

	# Any party member can pull everyone out of an expedition (matches the
	# couch behavior where either pad can retreat).
	var dungeon_retreat := func(_sender: int, _args: Dictionary) -> Dictionary:
		var d: Node = Net.get_tree().get_first_node_in_group("dungeon_runtime")
		if d == null:
			return {"ok": false}
		d._finish(false, false)
		return {"ok": true}
	reg["dungeon.retreat"] = {"run": dungeon_retreat, "syncs": []}

	# ---- expedition lineup: every player picks their own hero + belt --------
	var lineup_begin := func(_sender: int, args: Dictionary) -> Dictionary:
		DungeonManager.lineup_pending = {"world_id": String(args.get("world_id", "")),
			"slice": bool(args.get("slice", false)), "picks": {}}
		Net.broadcast_scene_event("lineup_open", {
			"world_id": String(args.get("world_id", "")),
			"slice": bool(args.get("slice", false))})
		return {"ok": true}
	reg["lineup.begin"] = {"run": lineup_begin, "syncs": []}

	var lineup_set := func(sender: int, args: Dictionary) -> Dictionary:
		var lp: Dictionary = DungeonManager.lineup_pending
		if lp.is_empty():
			return {"ok": false}
		(lp["picks"] as Dictionary)[sender] = {
			"hero_id": String(args.get("hero_id", "")),
			"consumables": args.get("consumables", [])}
		var needed: int = PartyState.connected_indexes().size()
		if (lp["picks"] as Dictionary).size() >= needed:
			var err: String = GatesPanel.depart_party(String(lp.get("world_id", "")),
				bool(lp.get("slice", false)), lp["picks"])
			if err != "":
				(lp["picks"] as Dictionary).clear()
				Net.broadcast_scene_event("lineup_failed", {"reason": err})
			else:
				DungeonManager.lineup_pending = {}
		else:
			Net.broadcast_scene_event("lineup_progress",
				{"count": (lp["picks"] as Dictionary).size(), "needed": needed})
		return {"ok": true}
	reg["lineup.set"] = {"run": lineup_set, "syncs": []}

	var lineup_cancel := func(_sender: int, _args: Dictionary) -> Dictionary:
		DungeonManager.lineup_pending = {}
		Net.broadcast_scene_event("lineup_cancelled", {})
		return {"ok": true}
	reg["lineup.cancel"] = {"run": lineup_cancel, "syncs": []}

	var bridge_pay_repair := func(_sender: int, args: Dictionary) -> Dictionary:
		var ok: bool = BridgeManager.pay_repair(String(args.get("world_id", "")))
		if ok:
			AudioManager.play_stinger("victory_stinger")
			SaveManager.checkpoint_chapter()
		return {"ok": ok}
	reg["bridge.pay_repair"] = {"run": bridge_pay_repair,
		"syncs": ["bridge", "economy", "time", "game_state"]}

	var menu_release := func(sender: int, args: Dictionary) -> Dictionary:
		var key := String(args.get("key", ""))
		var claim: Dictionary = Net.menu_claims.get(key, {})
		if int(claim.get("idx", 0)) == sender:
			Net.menu_claims.erase(key)
		return {"ok": true}
	reg["menu.release"] = {"run": menu_release, "syncs": []}

	return reg
