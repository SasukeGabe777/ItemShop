extends Node
## EconomyManager: gold, transactions, sale bookkeeping and the merchant combo.

signal gold_changed(gold: int)
signal sale_completed(item_id: String, price: int, customer_id: String)

var gold: int = 0
var combo: int = 0  # consecutive first-offer successes
var lifetime_earned: int = 0
var lifetime_spent: int = 0
var day_sales: Array = []  # [{item, price}] sold today (runtime only, for summaries)


func _ready() -> void:
	# day-enders snapshot day_sales BEFORE calling TimeManager.advance —
	# this wipe runs during the advance, as the new day starts
	TimeManager.day_started.connect(func(_d: int) -> void: day_sales.clear())


func reset() -> void:
	gold = int(ContentDatabase.bal("starting_gold", 1000))
	combo = 0
	lifetime_earned = 0
	lifetime_spent = 0
	day_sales.clear()
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
	record_bulk_sale(item_id, price, customer_id, first_offer, perfect, 1)


## One negotiation may represent several inexpensive Boom goods. Inventory is
## removed by Negotiation; this records each physical item for summaries and
## progression while treating the bundle as one haggle/combo result.
func record_bulk_sale(item_id: String, total_price: int, customer_id: String, first_offer: bool, perfect: bool, quantity: int) -> void:
	var qty := maxi(1, quantity)
	var unit_price := total_price / qty
	var remainder := total_price - unit_price * qty
	for i in range(qty):
		day_sales.append({"item": item_id, "price": unit_price + (remainder if i == 0 else 0)})
	add_gold(total_price)
	GameState.add_stat("sales", qty)
	GameState.learn_item(item_id)
	var mx: Dictionary = ContentDatabase.bal("merchant_xp", {})
	GameState.add_merchant_xp(int(mx.get("per_sale", 4)) * qty)
	if perfect:
		GameState.add_stat("perfect_deals")
		GameState.add_merchant_xp(int(mx.get("per_perfect", 10)))
	if first_offer:
		combo += 1
	else:
		combo = 0
	for i in range(qty):
		sale_completed.emit(item_id, unit_price + (remainder if i == 0 else 0), customer_id)


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
