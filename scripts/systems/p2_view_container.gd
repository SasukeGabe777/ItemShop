extends SubViewportContainer
## P2's screen half. SubViewportContainer normally forwards EVERY input event
## from the root into its viewport — which let Player 1's pad drive Player 2's
## menus. Forwarding is disabled entirely: MultiplayerState's device-1 pump is
## the only way input reaches this viewport.


func _propagate_input_event(_event: InputEvent) -> bool:
	return false
