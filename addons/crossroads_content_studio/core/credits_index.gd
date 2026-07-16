@tool
class_name CCSCreditsIndex
extends RefCounted
## Merges credit/source metadata from credits/ASSET_CREDITS.csv,
## credits/MUSIC_CREDITS.csv, and any per-franchise
## credits/sprite_resource_downloader/<franchise>/ASSET_MANIFEST.json written
## by the downloader, keyed by asset id (the file's basename without
## extension). Read-only: never writes back to any credits file.

const ASSET_CREDITS_CSV := "res://credits/ASSET_CREDITS.csv"
const MUSIC_CREDITS_CSV := "res://credits/MUSIC_CREDITS.csv"
const DOWNLOADER_CREDITS_ROOT := "res://credits/sprite_resource_downloader"

var by_asset_id: Dictionary = {}
var by_track_id: Dictionary = {}


func build() -> void:
	by_asset_id.clear()
	by_track_id.clear()
	_load_csv(ASSET_CREDITS_CSV, "asset_id", by_asset_id)
	_load_csv(MUSIC_CREDITS_CSV, "track_id", by_track_id)
	_load_downloader_manifests()


func lookup_for_path(res_path: String) -> Dictionary:
	var stem := res_path.get_file().get_basename()
	return by_asset_id.get(stem, {})


func lookup_for_track(track_id: String) -> Dictionary:
	return by_track_id.get(track_id, {})


func _load_csv(path: String, id_column: String, out: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var header := f.get_csv_line()
	while f.get_position() < f.get_length():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		var rec: Dictionary = {}
		for i in range(min(header.size(), row.size())):
			rec[header[i]] = row[i]
		var id := String(rec.get(id_column, ""))
		if id != "":
			out[id] = rec
	f.close()


func _load_downloader_manifests() -> void:
	var franchises := CCSFileOps.list_subdirs(DOWNLOADER_CREDITS_ROOT)
	for franchise in franchises:
		var path := "%s/%s/ASSET_MANIFEST.json" % [DOWNLOADER_CREDITS_ROOT, franchise]
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if not (parsed is Array):
			continue
		for entry: Dictionary in parsed:
			var id := String(entry.get("asset_id", ""))
			if id == "":
				continue
			if by_asset_id.has(id):
				for key in entry:
					if not by_asset_id[id].has(key):
						by_asset_id[id][key] = entry[key]
			else:
				by_asset_id[id] = entry
