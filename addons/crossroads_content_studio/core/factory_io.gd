@tool
class_name CCSFactoryIO
extends RefCounted
## Write-side helpers for the Asset Factory tabs: id/filename sanitizing,
## data/*.json upserts (the studio's read-only CCSContentScan stays the read
## side), sprite-sheet manifest writing, and sidecar metadata for every file
## the factory copies. All JSON is written with the project's two-space
## indent style and a trailing newline.

const SIDE_CAR_SUFFIX := ".meta.json"


## "Sea-Salt Ice Cream!" -> "sea_salt_ice_cream". Never returns "".
static func sanitize_id(name: String) -> String:
	var out := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_"):
			out += "_"
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	return out if out != "" else "unnamed"


static func sanitize_filename(name: String) -> String:
	return sanitize_id(name)


## Appends _2, _3... until the id is free in `taken` (any Dictionary keyed by id).
static func unique_id(base: String, taken: Dictionary) -> String:
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


static func load_doc(res_path: String) -> Dictionary:
	if not FileAccess.file_exists(res_path):
		return {}
	var f := FileAccess.open(res_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func save_doc(res_path: String, doc: Dictionary) -> String:
	CCSFileOps.ensure_dir(res_path.get_base_dir())
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % res_path
	f.store_string(JSON.stringify(doc, "  ") + "\n")
	return ""


## Inserts or replaces the entry with entry.id inside doc[array_key] of a
## data file, creating the document (with its schema tag) if it is missing.
## Returns "" on success or an error message.
static func upsert_entry(res_path: String, array_key: String, schema_tag: String, entry: Dictionary) -> String:
	if String(entry.get("id", "")) == "":
		return "entry has no id"
	var doc := load_doc(res_path)
	if doc.is_empty():
		doc = {"schema": schema_tag, array_key: []}
	if not doc.has(array_key):
		doc[array_key] = []
	var arr: Array = doc[array_key]
	var replaced := false
	for i in arr.size():
		if str((arr[i] as Dictionary).get("id", "")) == String(entry["id"]):
			arr[i] = entry
			replaced = true
			break
	if not replaced:
		arr.append(entry)
	return save_doc(res_path, doc)


static func find_entry(res_path: String, array_key: String, id: String) -> Dictionary:
	for e in load_doc(res_path).get(array_key, []):
		if str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


static func delete_entry(res_path: String, array_key: String, id: String) -> String:
	var doc := load_doc(res_path)
	if not doc.has(array_key):
		return "no such data file / key"
	var arr: Array = doc[array_key]
	for i in arr.size():
		if str((arr[i] as Dictionary).get("id", "")) == id:
			arr.remove_at(i)
			return save_doc(res_path, doc)
	return "id '%s' not found" % id


## Copies a file and records where it came from in a sidecar JSON next to the
## destination. Refuses to overwrite unless `overwrite` is true (callers show
## a confirmation dialog first).
static func copy_with_sidecar(src_res_path: String, dest_res_path: String, meta: Dictionary = {}, overwrite: bool = false) -> String:
	if FileAccess.file_exists(dest_res_path) and not overwrite:
		return "destination exists (needs confirmation): %s" % dest_res_path
	var err := CCSFileOps.copy_file(src_res_path, dest_res_path)
	if err != "":
		return err
	return write_sidecar(dest_res_path, meta.merged({"original_source": src_res_path}))


static func write_sidecar(dest_res_path: String, meta: Dictionary) -> String:
	var doc := meta.duplicate()
	doc["written_by"] = "crossroads_asset_factory"
	doc["written_at"] = Time.get_datetime_string_from_system()
	return save_doc(dest_res_path + SIDE_CAR_SUFFIX, doc)


## Saves an entity animation manifest where the runtime reads it
## (assets/franchises/<world>/manifests/<id>.json) — the SpriteFramesBuilder
## schema: sheet, pivot, grid, animations{name: {frames|rects, fps, loop}}.
static func save_manifest(world_id: String, entity_id: String, manifest: Dictionary) -> String:
	var path := CCSAssetPaths.manifest_path(world_id, entity_id)
	return save_doc(path, manifest)


static func rescan_filesystem() -> void:
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs != null:
			fs.scan()
