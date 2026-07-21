class_name Negotiation
## Pure negotiation logic shared by the shop UI and headless simulations.
## A negotiation is created per customer+item; the player proposes prices and
## the customer answers with one of the RESULT_* outcomes.

const RESULT_PERFECT := "perfect_deal"
const RESULT_ACCEPT := "accept"
const RESULT_COUNTER := "counteroffer"
const RESULT_FINAL_WARNING := "final_warning"
const RESULT_LEAVE := "leave"

var customer: Dictionary          # runtime customer (see CustomerGen)
var item_id: String
var market_value: int
var quantity: int = 1
var tolerance: float              # max acceptable price ratio vs market value
var budget: int
var rounds_left: int
var first_offer: bool = true
var warned: bool = false
var log: Array[String] = []


static func start(cust: Dictionary, target_item: String) -> Negotiation:
	var n := Negotiation.new()
	n.customer = cust
	n.item_id = target_item
	n.quantity = BoomManager.purchase_quantity(cust, target_item)
	n.market_value = MarketManager.market_value(target_item) * n.quantity
	n.budget = int(cust.get("budget", 500))
	var cfg: Dictionary = ContentDatabase.bal("negotiation", {})
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "adventurer")))
	var tol := float(arch.get("markup_tolerance", 1.3))
	# relationship: each level adds tolerance
	var rel_level := RelationshipManager.level(String(cust.get("id", "")))
	tol += rel_level * float(cfg.get("relationship_markup_per_level", 0.04))
	# item preference
	if CustomerGen.likes_item(cust, target_item):
		tol += float(cfg.get("preference_bonus", 0.2))
	# shop appeal match
	if InventoryManager.dominant_appeal() == String(arch.get("appeal_pref", "")):
		tol += float(cfg.get("appeal_match_bonus", 0.1))
	# today's mood
	tol += RelationshipManager.mood(String(cust.get("id", ""))) * float(cfg.get("mood_swing", 0.12))
	# merchant skill
	var mx: Dictionary = ContentDatabase.bal("merchant_xp", {})
	tol += GameState.merchant_level * float(mx.get("haggle_bonus_per_level", 0.01))
	# combo bonus makes crowds slightly more agreeable
	tol += EconomyManager.combo_bonus() * 0.1
	# A shop dressed for the announced Boom earns extra enthusiasm, but the
	# customer's normal archetype, relationship, mood, and purse still matter.
	tol += BoomManager.negotiation_tolerance_bonus()
	n.tolerance = maxf(1.02, tol)
	n.rounds_left = int(cfg.get("counter_rounds", 2))
	return n


func max_acceptable() -> int:
	return mini(budget, int(round(market_value * tolerance)))


func perfect_floor() -> int:
	var cfg: Dictionary = ContentDatabase.bal("negotiation", {})
	var window := float(cfg.get("perfect_window", 0.06))
	return int(round(market_value * (tolerance - window)))


## Customer's counteroffer proposal.
func counter_price() -> int:
	var arch: Dictionary = ContentDatabase.get_archetype(String(customer.get("archetype", "adventurer")))
	var haggle := float(arch.get("haggle", 0.4))
	var target := market_value * lerpf(tolerance * 0.92, 1.0, haggle * 0.5)
	return mini(budget, int(round(target)))


## True when the wallet (not willingness) is what limits their counteroffer —
## they would pay more for this item if they had the coin.
func counter_is_budget_capped() -> bool:
	return counter_price() >= budget


## Evaluate a proposed price. Returns
## {result, price, relationship_delta, perfect, message}.
func propose(price: int) -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("negotiation", {})
	var cap := max_acceptable()
	var was_first := first_offer
	first_offer = false
	if price <= 0:
		return _res(RESULT_LEAVE, 0, -1, false, "That isn't a price.")
	if price <= cap:
		var perfect := price >= perfect_floor() and price <= cap
		var generous := price < market_value
		var rel := int(cfg.get("relationship_gain_perfect", 2)) if perfect else int(cfg.get("relationship_gain_sale", 1))
		if generous:
			rel += 1
		var msg := "A perfect deal!" if perfect else ("What a bargain!" if generous else "Deal!")
		return _res(RESULT_PERFECT if perfect else RESULT_ACCEPT, price, rel, perfect, msg, was_first)
	# too expensive
	var over_ratio := float(price) / maxf(1.0, float(cap))
	if warned or rounds_left <= 0:
		EconomyManager.break_combo()
		var loss := int(cfg.get("relationship_loss_reject", 1))
		if over_ratio > 1.5:
			loss = int(cfg.get("relationship_loss_gouge", 2))
		return _res(RESULT_LEAVE, 0, -loss, false, "Forget it! I'm leaving.")
	var capped := counter_is_budget_capped()
	if over_ratio >= float(cfg.get("final_warning_threshold", 1.12)) and rounds_left == 1:
		warned = true
		rounds_left -= 1
		var warn_msg := "This is my FINAL offer. My purse holds nothing more." if capped else "This is my FINAL offer."
		return _res(RESULT_FINAL_WARNING, counter_price(), 0, false, warn_msg, false, capped)
	rounds_left -= 1
	var counter_msg := "I want it, truly — but this is everything I have." if capped else "Hmm... how about this instead?"
	return _res(RESULT_COUNTER, counter_price(), 0, false, counter_msg, false, capped)


func _res(result: String, price: int, rel_delta: int, perfect: bool, message: String, was_first: bool = false, budget_capped: bool = false) -> Dictionary:
	log.append("%s -> %s" % [result, price])
	return {
		"result": result, "price": price, "relationship_delta": rel_delta,
		"perfect": perfect, "message": message, "first_offer": was_first,
		"budget_capped": budget_capped,
	}


## Complete a successful sale: transfers item, gold, relationship, orders.
func finalize_sale(outcome: Dictionary) -> void:
	var cid := String(customer.get("id", ""))
	InventoryManager.remove_from_display(item_id)
	if quantity > 1:
		InventoryManager.remove_item(item_id, quantity - 1)
	outcome["quantity"] = quantity
	EconomyManager.record_bulk_sale(item_id, int(outcome["price"]), cid,
		bool(outcome.get("first_offer", false)), bool(outcome.get("perfect", false)), quantity)
	RelationshipManager.change_relationship(cid, int(outcome["relationship_delta"]))
	GameState.know_customer(cid)
	var slice_cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	var active_flag := String(slice_cfg.get("active_flag", ""))
	var completion_flag := String(slice_cfg.get("completion_flag", ""))
	if active_flag != "" and GameState.has_flag(active_flag) and completion_flag != "" and not GameState.has_flag(completion_flag):
		var starter_flag := String(slice_cfg.get("starter_sale_flag", ""))
		if starter_flag != "":
			GameState.set_flag(starter_flag)
	elif active_flag != "" and GameState.has_flag(active_flag) and item_id == String(slice_cfg.get("reward_item_id", "")):
		var reward_sale_flag := String(slice_cfg.get("reward_sale_flag", ""))
		if reward_sale_flag != "":
			GameState.set_flag(reward_sale_flag)
	# selling equipment to a franchise hero updates their loadout when better
	var hero_ref := String(customer.get("hero_ref", ""))
	if hero_ref != "":
		CustomerGen.try_hero_autoequip(hero_ref, item_id)
		RelationshipManager.change_relationship(hero_ref, 1)
