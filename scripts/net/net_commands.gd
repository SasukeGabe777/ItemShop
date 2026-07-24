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

	return reg
