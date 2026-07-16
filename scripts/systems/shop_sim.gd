class_name ShopSim
## Headless shop-session driver. Runs a full "open the shop" period without UI,
## using the same CustomerGen + Negotiation logic as the interactive scene.
## price_factor: proposed price as a multiple of market value.


static func run_session(price_factor: float = 1.25) -> Dictionary:
	var results := {"customers": 0, "sales": 0, "revenue": 0, "perfect": 0, "left": 0, "orders": 0}
	var customers := CustomerGen.generate_session_customers()
	results["customers"] = customers.size()
	for cust in customers:
		var interest := CustomerGen.pick_interest(cust)
		if interest == "":
			if not CustomerGen.maybe_make_order(cust).is_empty():
				results["orders"] = int(results["orders"]) + 1
			continue
		var nego := Negotiation.start(cust, interest)
		var outcome := nego.propose(int(round(nego.market_value * price_factor)))
		var tries := 3
		while tries > 0 and outcome["result"] in [Negotiation.RESULT_COUNTER, Negotiation.RESULT_FINAL_WARNING]:
			# meet the customer's counter
			outcome = nego.propose(int(outcome["price"]))
			tries -= 1
		match String(outcome["result"]):
			Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT:
				nego.finalize_sale(outcome)
				results["sales"] = int(results["sales"]) + 1
				results["revenue"] = int(results["revenue"]) + int(outcome["price"])
				if bool(outcome["perfect"]):
					results["perfect"] = int(results["perfect"]) + 1
			_:
				results["left"] = int(results["left"]) + 1
				RelationshipManager.change_relationship(String(cust.get("id", "")), int(outcome["relationship_delta"]))
		# order chance after interaction too
		if not CustomerGen.maybe_make_order(cust).is_empty():
			results["orders"] = int(results["orders"]) + 1
	return results


## Auto-restock helper for simulations: fill display slots from storage,
## most valuable first.
static func auto_stock_display() -> void:
	for slot in range(InventoryManager.display.size()):
		if String(InventoryManager.display[slot]) != "":
			continue
		var ids := InventoryManager.sorted_ids("price")
		for id in ids:
			var it := ContentDatabase.get_item(id)
			if it.get("sellable", true) == false:
				continue
			if String(it.get("category", "")) == "key":
				continue
			InventoryManager.place_display(slot, id)
			break


## Auto-buy wholesale stock for simulations: spend up to budget_ratio of gold
## on goods with the best market multipliers.
static func auto_buy_stock(budget_ratio: float = 0.5) -> int:
	var budget := int(EconomyManager.gold * budget_ratio)
	var catalog := MarketManager.wholesale_catalog()
	if catalog.is_empty():
		return 0
	# prefer items with high sale value relative to wholesale cost
	catalog.sort_custom(func(a: String, b: String) -> bool:
		return MarketManager.market_value(a) - MarketManager.wholesale_cost(a) > MarketManager.market_value(b) - MarketManager.wholesale_cost(b))
	var spent := 0
	var idx := 0
	while budget > 0 and idx < catalog.size():
		var id := catalog[idx]
		var cost := MarketManager.wholesale_cost(id)
		if cost <= budget and EconomyManager.spend_gold(cost):
			InventoryManager.add_item(id)
			budget -= cost
			spent += cost
		else:
			idx += 1
	return spent
