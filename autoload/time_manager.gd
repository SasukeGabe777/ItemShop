extends Node
## TimeManager: 35-day campaign clock. Four periods per day. Chapters of five
## days with a deadline check at the end of each chapter's final day.

signal day_started(day: int)
signal period_advanced(day: int, period: int)
signal chapter_started(chapter: int)
signal chapter_deadline_failed(chapter: int)
signal campaign_won()

var day: int = 1
var period: int = 0  # 0..3
var chapter: int = 1


func campaign_days() -> int:
	return int(ContentDatabase.bal("campaign_days", 35))


func chapter_len() -> int:
	return int(ContentDatabase.bal("chapter_length_days", 5))


func periods_per_day() -> int:
	return int(ContentDatabase.bal("periods_per_day", 4))


func period_name() -> String:
	var names: Array = ContentDatabase.bal("period_names", ["Morning", "Afternoon", "Evening", "Night"])
	return String(names[clampi(period, 0, names.size() - 1)])


func activity_cost(activity: String) -> int:
	var costs: Dictionary = ContentDatabase.bal("activity_costs", {})
	return int(costs.get(activity, 1))


func chapter_deadline_day() -> int:
	return chapter * chapter_len()


func days_left_in_chapter() -> int:
	return chapter_deadline_day() - day


func reset(start_chapter: int = 1) -> void:
	chapter = start_chapter
	day = (start_chapter - 1) * chapter_len() + 1
	period = 0


## Spend one or more periods. Returns events that occurred, e.g. ["day_end", "deadline_failed"].
func advance(periods: int) -> Array[String]:
	var events: Array[String] = []
	for i in range(periods):
		period += 1
		if period >= periods_per_day():
			events.append_array(_end_day())
			if "deadline_failed" in events or "campaign_won" in events:
				break
		period_advanced.emit(day, period)
	return events


func _end_day() -> Array[String]:
	var events: Array[String] = ["day_end"]
	# Deadline check at the end of a chapter's final day (chapters 1-7 only;
	# the final chapter has no deadline, and endless mode has none at all).
	if GameState.campaign_active and not GameState.endless_mode and chapter <= 7 \
			and day == chapter_deadline_day() and not BridgeManager.is_chapter_complete(chapter):
		chapter_deadline_failed.emit(chapter)
		events.append("deadline_failed")
		return events
	day += 1
	period = 0
	GameState.add_stat("days_played")
	if GameState.endless_mode:
		var endless_cfg: Dictionary = ContentDatabase.bal("endless", {})
		var days_in := maxi(0, day - campaign_days())
		var rent := int(round(float(endless_cfg.get("daily_rent", 500)) * pow(float(endless_cfg.get("rent_growth", 1.05)), days_in)))
		EconomyManager.add_gold(-mini(rent, EconomyManager.gold))
	MarketManager.on_new_day()
	day_started.emit(day)
	events.append("new_day")
	return events


## Called by BridgeManager when a repair completes to begin the next chapter.
func begin_chapter(new_chapter: int) -> void:
	chapter = new_chapter
	chapter_started.emit(chapter)


func to_save() -> Dictionary:
	return {"day": day, "period": period, "chapter": chapter}


func from_save(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	period = int(d.get("period", 0))
	chapter = int(d.get("chapter", 1))
