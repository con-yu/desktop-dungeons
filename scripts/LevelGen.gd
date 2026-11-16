class_name LevelGen
extends RefCounted

## 单屏洞穴生成：随机噪声 -> 元胞自动机平滑 -> 连通性修复。

const W := GameConfig.GRID_W
const H := GameConfig.GRID_H

const WALL := 1
const FLOOR := 0


static func generate(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	for attempt in 24:
		var tiles := _carve(rng)
		var cells := _largest_region(tiles)
		if cells.size() < 180:
			continue
		tiles = _keep_only(tiles, cells)
		var start := _pick_start(cells, rng)
		if start.x < 0:
			continue
		var boss_pos := _pick_farthest(cells, start)
		var slots: Array[Vector2i] = []
		for c in cells:
			if c == start or c == boss_pos:
				continue
			if _manhattan(c, start) < 5:
				continue
			slots.append(c)
		_shuffle(slots, rng)
		return {
			"tiles": tiles,
			"floor_cells": cells,
			"slots": slots,
			"start": start,
			"boss_pos": boss_pos,
		}
	# 极端兜底：整块平地
	var flat := PackedByteArray()
	flat.resize(W * H)
	for i in W * H:
		var x := i % W
		var y := i / W
		flat[i] = WALL if (x == 0 or y == 0 or x == W - 1 or y == H - 1) else FLOOR
	var all_cells: Array[Vector2i] = []
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			all_cells.append(Vector2i(x, y))
	return {
		"tiles": flat,
		"floor_cells": all_cells,
		"slots": all_cells.slice(20),
		"start": Vector2i(2, 2),
		"boss_pos": Vector2i(W - 3, H - 3),
	}


static func _carve(rng: RandomNumberGenerator) -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(W * H)
	for y in H:
		for x in W:
			var i := y * W + x
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				t[i] = WALL
			else:
				t[i] = WALL if rng.randf() < 0.20 else FLOOR
	# 一次平滑：让石块聚成块状，同时保留零散石柱
	var out := t.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var walls := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if t[(y + dy) * W + (x + dx)] == WALL:
						walls += 1
			out[y * W + x] = WALL if walls >= 5 else FLOOR
	return out


static func _largest_region(tiles: PackedByteArray) -> Array[Vector2i]:
	var seen := {}
	var best: Array[Vector2i] = []
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var start := Vector2i(x, y)
			if tiles[y * W + x] == WALL or seen.has(start):
				continue
			var region: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				region.append(c)
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var n: Vector2i = c + d
					if n.x <= 0 or n.y <= 0 or n.x >= W - 1 or n.y >= H - 1:
						continue
					if seen.has(n) or tiles[n.y * W + n.x] == WALL:
						continue
					seen[n] = true
					stack.append(n)
			if region.size() > best.size():
				best = region
	return best


static func _keep_only(tiles: PackedByteArray, cells: Array[Vector2i]) -> PackedByteArray:
	var keep := {}
	for c in cells:
		keep[c] = true
	var out := tiles.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if tiles[y * W + x] == FLOOR and not keep.has(Vector2i(x, y)):
				out[y * W + x] = WALL
	return out


static func _pick_start(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	# 尽量靠左侧，留出向右推进的空间；要求 3x3 开阔
	var candidates: Array[Vector2i] = []
	for c in cells:
		if c.x > W / 3:
			continue
		if _open3x3(cells, c):
			candidates.append(c)
	if candidates.is_empty():
		for c in cells:
			if _open3x3(cells, c):
				candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _open3x3(cells: Array[Vector2i], c: Vector2i) -> bool:
	var grid := {}
	for v in cells:
		grid[v] = true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not grid.has(c + Vector2i(dx, dy)):
				return false
	return true


static func _pick_farthest(cells: Array[Vector2i], from: Vector2i) -> Vector2i:
	var best := from
	var best_d := -1
	for c in cells:
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d > best_d:
			best_d = d
			best = c
	return best


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
