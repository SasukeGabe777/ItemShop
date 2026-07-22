extends Node
## Headless checks for shop gold art, customer feedback, bond art, patience,
## private purses, and stable one-character/one-archetype identities.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	BoomManager.reset()
	_check_assets()
	_check_negotiation()
	_check_identities()
	_check_bonds_and_gold_drop()
	if failures.is_empty():
		print("SHOP_FEEDBACK_PROBE_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_assets() -> void:
	for path in [UIKit.GOLD_SMALL, UIKit.GOLD_MEDIUM, UIKit.GOLD_LARGE]:
		check(ResourceLoader.exists(path), "missing gold art: %s" % path)
	for kind in ["unhappy", "boom", "happy", "overpaid", "neutral", "wealthy"]:
		check(UIKit.emote_texture(kind) != null, "missing emote: %s" % kind)
	for level in range(1, 6):
		check(ResourceLoader.exists(UIKit.BOND_PATTERN % level), "missing bond art: %d" % level)


func _customer(id: String = "probe_customer") -> Dictionary:
	return {"id": id, "name": "Probe", "archetype": "adventurer", "budget": 500,
		"hero_ref": "", "world": "", "named": false}


func _check_negotiation() -> void:
	Negotiation.rng.seed = 20260721
	var outrage := Negotiation.start(_customer(), "kh_potion")
	var result := outrage.propose(maxi(1, outrage.max_acceptable()) * 2)
	check(String(result.get("result", "")) == Negotiation.RESULT_LEAVE, "absurd offer did not cause immediate walkaway")
	check(String(result.get("emote", "")) == "unhappy", "walkaway did not request unhappy emote")
	check("ridiculous" in String(result.get("message", "")).to_lower(), "walkaway copy is missing")

	var patience_seen: Dictionary = {}
	for i in range(90):
		var n := Negotiation.start(_customer("patience_%d" % i), "kh_potion")
		patience_seen[n.max_rejections] = true
		var answer := n.propose(int(round(n.max_acceptable() * 1.2)))
		var words := String(answer.get("message", "")).to_lower()
		check("every coin" not in words and "everything i have" not in words and "purse holds" not in words,
			"negotiation revealed the exact wallet")
	check(patience_seen.has(1) and patience_seen.has(2) and patience_seen.has(3),
		"patience did not cover one, two, and three haggles: %s" % patience_seen)


func _check_identities() -> void:
	var moogle := ContentDatabase.customer_pool_entry_by_name("Moogle Broker")
	check(not moogle.is_empty(), "Moogle visual identity not found")
	check(CustomerGen._identity_archetype(moogle) == "traveling_merchant", "Moogle identity changed archetype")
	CustomerGen.rng.seed = 271828
	var session := CustomerGen.generate_session_customers()
	var used: Dictionary = {}
	for cust: Dictionary in session:
		var slug := String(cust.get("visual_slug", cust.get("id", "")))
		check(slug != "", "customer has no stable visual identity")
		check(not used.has(slug), "visual identity repeated in one session: %s" % slug)
		used[slug] = true
		if not bool(cust.get("named", false)):
			var entry := ContentDatabase.customer_visual_pool.filter(func(e: Dictionary) -> bool:
				return String(e.get("slug", "")) == slug)
			if not entry.is_empty():
				check(String(cust.get("archetype", "")) == CustomerGen._identity_archetype(entry[0]),
					"identity/archetype mapping drifted for %s" % slug)


func _check_bonds_and_gold_drop() -> void:
	RelationshipManager.change_relationship("bond_probe", 999)
	check(RelationshipManager.level("bond_probe") == 5, "bond level does not cap at the five supplied tiers")
	var drop := LootPickup.new()
	add_child(drop)
	drop.setup_gold(500)
	var sprites := drop.get_children().filter(func(child: Node) -> bool: return child is Sprite2D)
	check(not sprites.is_empty(), "gold drop has no sprite")
	if not sprites.is_empty():
		check((sprites[0] as Sprite2D).texture == UIKit.gold_texture("large"), "large gold drop did not use the supplied pile")
		var drop_sprite := sprites[0] as Sprite2D
		var rendered_max := maxf(drop_sprite.texture.get_width() * drop_sprite.scale.x,
			drop_sprite.texture.get_height() * drop_sprite.scale.y)
		check(rendered_max <= 18.1, "gold drop is larger than the item-drop reference: %.1f px" % rendered_max)
	drop.queue_free()
	var popup_parent := Node2D.new()
	add_child(popup_parent)
	var popup := UIKit.gold_popup(popup_parent, 750)
	var popup_sprite := popup.get_children().filter(func(child: Node) -> bool: return child is Sprite2D)[0] as Sprite2D
	var popup_max := maxf(popup_sprite.texture.get_width() * popup_sprite.scale.x,
		popup_sprite.texture.get_height() * popup_sprite.scale.y)
	check(popup_max <= 30.1, "sale popup exceeds its world-space cap: %.1f px" % popup_max)


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SHOP_FEEDBACK_PROBE_FAIL: " + message)
