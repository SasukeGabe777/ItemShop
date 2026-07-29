extends Node
## Loads the player's real second save slot read-only and protects the exact
## first-load contracts that failed during the core-loop hardening pass.

var failures: Array[String] = []


func _ready() -> void:
	AudioManager.set_muted(true)
	_load_regression_state()
	_check_active_events()
	_check_relationship_copy()
	_check_negotiation_read()
	_check_town_facing()
	if failures.is_empty():
		print("SAVE2_REGRESSION_PROBE_PASS")
	else:
		for message in failures:
			printerr("SAVE2_REGRESSION_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _load_regression_state() -> void:
	var loaded_exact_slot := SaveManager.load_from_slot(2) \
		and TimeManager.chapter == 5 and TimeManager.day == 15
	if loaded_exact_slot:
		print("SAVE2_FIXTURE_SOURCE user://saves/slot_2.json")
		return
	# Portable fallback for clean machines: the relevant portion of the
	# reported save, without writing or packaging the player's full save.
	GameState.reset_campaign()
	TimeManager.from_save({"chapter": 5, "day": 15, "period": 1})
	MarketManager.from_save({"active_events": [
		{"days_left": 1, "id": "bottle_deposit"},
		{"days_left": 2, "id": "shard_glut"},
	]})
	RelationshipManager.from_save({"relationships": {
		"moogle_c": 42, "moogle_ff_c": 4, "peach_c": 6,
	}})
	print("SAVE2_FIXTURE_SOURCE embedded Chapter 5 / Day 15 state")


func _check_active_events() -> void:
	var ids: Array[String] = []
	for event: Dictionary in MarketManager.active_event_details():
		var event_id := String(event.get("id", ""))
		ids.append(event_id)
		var affected := MarketManager.event_affected_items(event_id)
		print("SAVE2_EVENT ", event_id, " affected=", affected.size(), " ", affected)
		check(not affected.is_empty(),
			"slot 2 event %s reports no currently obtainable items" % event_id)
	check("bottle_deposit" in ids and "shard_glut" in ids,
		"slot 2 active market events changed during load")


func _check_relationship_copy() -> void:
	var threshold_id := "probe_threshold_customer"
	RelationshipManager.relationships[threshold_id] = 10
	var customer := {
		"id": threshold_id, "name": "Moogle", "archetype": "traveling_merchant",
		"budget": 500, "line": "Welcome to my shop, kupo!",
	}
	check(CustomerGen.conversation_opener(customer, "kh_potion") ==
		"Welcome to my shop, kupo!",
		"a brand-new Level 1 bond incorrectly claims a history of fair treatment")
	var progress := RelationshipManager.progress_text(threshold_id)
	check("10 total" in progress and "to Lv.2" in progress,
		"bond progress hides the customer's lifetime relationship points")


func _check_negotiation_read() -> void:
	var peach := CustomerGen.runtime_named(
		ContentDatabase.get_named_customer("peach_c"))
	peach["budget"] = 500000
	var negotiation := Negotiation.start(peach, "kh_potion")
	var shown_limit := negotiation.max_acceptable()
	check(shown_limit < negotiation.budget,
		"high-budget customer acceptance limit incorrectly equals the whole purse")
	var accepted := negotiation.propose(shown_limit)
	check(String(accepted.get("result", "")) in [
		Negotiation.RESULT_ACCEPT, Negotiation.RESULT_PERFECT],
		"the displayed maximum acceptable offer was rejected")


func _check_town_facing() -> void:
	var visual := CharacterVisual.new()
	add_child(visual)
	visual.setup_from_manifest("res://assets/hero/manifests/hero_faraway_overworld.json")
	visual.face(Vector2.LEFT, false)
	check(visual.animated.flip_h,
		"default town hero does not mirror its right-facing source art when moving left")
	visual.face(Vector2.RIGHT, false)
	check(not visual.animated.flip_h,
		"default town hero mirrors its source art when moving right")
	visual.queue_free()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
