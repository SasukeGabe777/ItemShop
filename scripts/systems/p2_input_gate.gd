extends Node
## Lives inside P2's SubViewport and consumes every input event that did NOT
## come from MultiplayerState's device-1 pump (tagged with meta "p2src").
## SubViewportContainer forwards root events into the viewport on some paths
## regardless of overrides — this gate guarantees Player 1's pad can never
## drive Player 2's menus.


func _input(event: InputEvent) -> void:
	if not event.get_meta("p2src", false):
		get_viewport().set_input_as_handled()
