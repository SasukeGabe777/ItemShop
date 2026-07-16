extends Node
## EconomyManager: gold, transactions, sale bookkeeping and the merchant combo.

signal gold_changed(gold: int)
signal sale_completed(item_id: String, price: int, customer_id: String)

var gold: int = 0
var combo: int = 0  # consecutive first-offer successes
var lifetime_earned: int = 0
var lifetime_spent: int = 0


func reset() -> void:
	gold = int(ContentDatabase.bal("starting_gold", 1000))
	combo = 0
	lifetime_earned = 0
	lifetime_spent = 0
	gold_changed.emit(gold)


func can_afford(amount: int) -> bool:
	return gold >= amount


func add_gold(amount: int) -> void:
	gold += amount
	lifetime_earned += maxi(0, amount)
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	lifetime_spent += amount
	gold_changed.emit(gold)
	return true


func combo_bonus() -> float:
	var shop: Dictionary = ContentDatabase.bal("shop", {})
	var per := float(shop.get("combo_bonus_per_perfect", 0.05))
	var cap := float(shop.get("combo_max", 0.5))
	return minf(cap, combo * per)


func record_sale(item_id: String, price: int, customer_id: String, first_offer: bool, perfect: bool) -> void:
	add_gold(price)
	GameState.add_stat("sales")
	GameState.learn_item(item_id)
	var mx: Dictionary = ContentDatabase.bal("merchant_xp", {})
	GameState.add_merchant_xp(int(mx.get("per_sale", 4)))
	if perfect:
		GameState.add_stat("perfect_deals")
		GameState.add_merchant_xp(int(mx.get("per_perfect", 10)))
	if first_offer:
		combo += 1
	else:
		combo = 0
	sale_completed.emit(item_id, price, customer_id)


func break_combo() -> void:
	combo = 0


func to_save() -> Dictionary:
	return {"gold": gold, "combo": combo, "lifetime_earned": lifetime_earned, "lifetime_spent": lifetime_spent}


func from_save(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	combo = int(d.get("combo", 0))
	lifetime_earned = int(d.get("lifetime_earned", 0))
	lifetime_spent = int(d.get("lifetime_spent", 0))
	gold_changed.emit(gold)
