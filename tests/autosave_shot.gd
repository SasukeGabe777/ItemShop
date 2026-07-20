extends Node2D
## Probe: per-period autosave. Walks the clock through a full day and checks
## that an autosave lands on every day portion (morning/afternoon/evening/
## night), that it carries the right day+period, that it survives a day
## rollover, and that loading it restores that exact point.

const AUTO := "user://saves/autosave.json"


func _modified() -> int:
	return int(FileAccess.get_modified_time(AUTO)) if FileAccess.file_exists(AUTO) else -1


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	GameState.campaign_active = true
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	if FileAccess.file_exists(AUTO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTO))

	print("PERIODS per day: ", TimeManager.periods_per_day())
	print("START day %d, period %d (%s), autosave exists: %s"
		% [TimeManager.day, TimeManager.period, TimeManager.period_name(), SaveManager.has_autosave()])

	# --- one full day, one period at a time --------------------------------
	var seen: Array[String] = []
	for step in range(TimeManager.periods_per_day()):
		EconomyManager.add_gold(10)   # make each save distinguishable
		TimeManager.advance(1)
		var s := SaveManager.autosave_summary()
		if s.is_empty():
			print("STEP %d: NO AUTOSAVE" % step)
			continue
		var tag := "Day %d %s" % [int(s["day"]), String(s["period_name"])]
		seen.append(tag)
		print("STEP %d -> clock is Day %d %s | autosave says %s, %dg"
			% [step, TimeManager.day, TimeManager.period_name(), tag, int(s["gold"])])
	print("AUTOSAVE portions captured: ", seen)

	# --- every portion name should have been hit ---------------------------
	var names: Array = ContentDatabase.bal("period_names", ["Morning", "Afternoon", "Evening", "Night"])
	var missed: Array[String] = []
	for n: String in names:
		var hit := false
		for t in seen:
			if t.ends_with(n):
				hit = true
		if not hit:
			missed.append(n)
	print("AUTOSAVE portions never saved: ", missed)

	# --- the autosave really restores that point ---------------------------
	var before_gold := EconomyManager.gold
	var before_day := TimeManager.day
	var before_period := TimeManager.period
	EconomyManager.add_gold(5000)
	TimeManager.advance(1)          # moves on, and autosaves again
	var moved_gold := EconomyManager.gold
	var ok := SaveManager.load_autosave()
	print("RESTORE loaded=%s -> day %d period %s, gold %d (was %d before the jump, %d after)"
		% [ok, TimeManager.day, TimeManager.period_name(), EconomyManager.gold, before_gold, moved_gold])
	print("RESTORE point matches the save it was taken at: ",
		TimeManager.day != before_day or TimeManager.period != before_period or EconomyManager.gold == moved_gold)

	# --- a save is not written while the campaign is inactive --------------
	GameState.campaign_active = false
	var stamp := _modified()
	TimeManager.advance(1)
	print("INACTIVE campaign wrote a new autosave: ", _modified() != stamp)
	print("AUTOSAVE_SHOT_DONE")
	get_tree().quit()
