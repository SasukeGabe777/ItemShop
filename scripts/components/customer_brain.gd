class_name CustomerBrain
extends Node
## Drives a customer entity through the shop: enter -> browse display slots ->
## decide -> negotiate (or leave). The shop scene listens to these signals.

signal wants_to_negotiate(customer: Dictionary, item_id: String)
signal wants_to_order(customer: Dictionary)
signal leaving()

enum State { ENTERING, BROWSING, DECIDING, NEGOTIATING, LEAVING }

var customer: Dictionary = {}
var state: State = State.ENTERING
var browse_time: float = 0.0
var target_slot: int = -1


func setup(cust: Dictionary) -> void:
	customer = cust
	state = State.ENTERING
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "")))
	browse_time = 1.2 + float(arch.get("patience", 3)) * 0.5


func tick(delta: float) -> void:
	match state:
		State.BROWSING:
			browse_time -= delta
			if browse_time <= 0.0:
				state = State.DECIDING
				_decide()
		_:
			pass


func begin_browsing() -> void:
	state = State.BROWSING


func _decide() -> void:
	var interest := CustomerGen.pick_interest(customer)
	if interest != "":
		state = State.NEGOTIATING
		wants_to_negotiate.emit(customer, interest)
	elif randf() < 0.5:
		wants_to_order.emit(customer)
		state = State.LEAVING
		leaving.emit()
	else:
		state = State.LEAVING
		leaving.emit()


func finish_negotiation() -> void:
	state = State.LEAVING
	leaving.emit()
