extends Node

## 数据表加载器（autoload: DB）

var classes: Dictionary = {}
var monsters: Dictionary = {}
var items: Dictionary = {}
var levels: Array = []
var progress: Dictionary = {"cleared": [], "best_level": 1}

const PROGRESS_PATH := "user://progress.json"

var _loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	if _loaded:
		return
	classes = _read_json("res://data/classes.json")
	monsters = _read_json("res://data/monsters.json")
	items = _read_json("res://data/items.json")
	var lv = _read_json("res://data/levels.json")
	levels = lv if lv is Array else []
	load_progress()
	_loaded = true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("缺少数据文件: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		push_error("JSON 解析失败: " + path)
		return {}
	return parsed


func level_def(index: int) -> Dictionary:
	if index < 0 or index >= levels.size():
		return {}
	return levels[index]


func monster_def(id: String) -> Dictionary:
	return monsters.get(id, {})


func item_def(id: String) -> Dictionary:
	return items.get(id, {})


func class_def(id: String) -> Dictionary:
	return classes.get(id, {})


func is_unlocked(index: int) -> bool:
	return index <= int(progress.get("best_level", 1)) - 1


func mark_cleared(index: int) -> void:
	var cleared: Array = progress.get("cleared", [])
	if not cleared.has(index):
		cleared.append(index)
	progress["cleared"] = cleared
	var best := int(progress.get("best_level", 1))
	if index + 1 >= best:
		progress["best_level"] = min(index + 2, levels.size())
	save_progress()


func save_progress() -> void:
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))
		f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		progress = parsed
		if not progress.has("best_level"):
			progress["best_level"] = 1
		if not progress.has("cleared"):
			progress["cleared"] = []
