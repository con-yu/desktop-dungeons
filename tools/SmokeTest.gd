extends Node

## 无头冒烟测试：每关 × 每职业 × 多局，用"近似真人"的策略验证规则、观察难度曲线。
## 运行：godot --headless tools/SmokeTest.tscn

const DIRS := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const RUNS := 2

var wins := 0
var deaths := 0
var stalls := 0


func _ready() -> void:
	print("=== 冒烟测试开始 ===")
	for i in DB.levels.size():
		var line := "第 %2d 关 %-8s |" % [i + 1, DB.level_def(i).get("name", "")]
		for cid in ["fighter", "wizard", "rogue"]:
			var w := 0
			var d := 0
			var s := 0
			var lv_sum := 0
			var turns := 0
			for run in RUNS:
				var st := DungeonState.new()
				st.new_run(i, cid, 0)
				_play(st)
				if st.victory:
					w += 1
					wins += 1
				elif st.player_dead:
					d += 1
					deaths += 1
				else:
					s += 1
					stalls += 1
				lv_sum += st.player.level
				turns += st.turn
			line += " %s 胜%d/亡%d/停%d Lv%.1f |" % [DB.class_def(cid).get("name", cid), w, d, s, float(lv_sum) / RUNS]
		print(line)
	print("=== 总计：胜 %d，亡 %d，未通关 %d ===" % [wins, deaths, stalls])
	get_tree().quit()


func _play(st: DungeonState) -> void:
	var guard := 0
	while guard < 2000 and not st.player_dead and not st.victory:
		guard += 1
		# 血量过低时喝药
		if st.player.hp < st.player.max_hp * 0.35 and st.items.has("potion_hp"):
			st.use_item("potion_hp")
			continue
		var stairs := _stairs(st)
		if stairs.x >= 0:
			var s1 := _toward_cell(st, stairs)
			if s1 != Vector2i.ZERO:
				st.player_action("move", s1)
				continue

		var target := _best_target(st)
		if target != Vector2i.ZERO:
			if _should_skill(st):
				st.player_action("skill")
			else:
				st.player_action("move", target)
			continue

		var step := _toward_unexplored(st)
		if step != Vector2i.ZERO:
			st.player_action("move", step)
			continue

		var far := _nearest_monster_dir(st)
		if far != Vector2i.ZERO:
			st.player_action("move", far)
			continue
		break


func _stairs(st: DungeonState) -> Vector2i:
	for c in st.props.keys():
		if String(st.props[c]) == "stairs":
			return c
	return Vector2i(-1, -1)


func _best_target(st: DungeonState) -> Vector2i:
	var hp_now := st.player.hp
	for d in DIRS:
		var m := st.monster_at(st.player.pos + d)
		if m == null:
			continue
		var dmg_out := maxi(1, st.player.atk - m.defense)
		var rounds := int(ceil(float(m.hp) / float(dmg_out)))
		var dmg_in := maxi(1, m.atk - st.player.defense) * maxi(0, rounds - 1)
		if dmg_in < hp_now * 0.8:
			return d
	for d in DIRS:
		if st.monster_at(st.player.pos + d) != null:
			return d
	return Vector2i.ZERO


func _should_skill(st: DungeonState) -> bool:
	var skill := String(st.class_data.get("skill_id", ""))
	var cost := int(st.class_data.get("skill_cost", 5))
	if st.player.mp < cost:
		return false
	match skill:
		"fireball":
			return st._nearest_monster(3) != null
		"stealth":
			return int(st.player.status.get("stealth", 0)) <= 0
		"smash":
			return st._adjacent_monster() != null
	return false


func _toward_unexplored(st: DungeonState) -> Vector2i:
	return _bfs(st, func(c: Vector2i) -> bool: return not st.is_explored(c), false)


func _nearest_monster_dir(st: DungeonState) -> Vector2i:
	return _bfs(st, func(c: Vector2i) -> bool: return st.monster_at(c) != null, true)


func _toward_cell(st: DungeonState, target: Vector2i) -> Vector2i:
	return _bfs(st, func(c: Vector2i) -> bool: return c == target, true)


## BFS 找满足条件的第一格，返回从玩家出发的第一步方向。
func _bfs(st: DungeonState, pred: Callable, allow_goal_blocked: bool) -> Vector2i:
	var from := st.player.pos
	if pred.call(from):
		return Vector2i.ZERO
	var q: Array[Vector2i] = [from]
	var first: Dictionary = {from: Vector2i.ZERO}
	var head := 0
	while head < q.size() and head < 1000:
		var cur: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if not st.in_bounds(nxt) or st.is_wall(nxt) or first.has(nxt):
				continue
			var blocked := st.monster_at(nxt) != null
			if blocked and not (allow_goal_blocked and pred.call(nxt)):
				continue
			var step: Vector2i = first[cur] if first[cur] != Vector2i.ZERO else d
			if pred.call(nxt):
				return step
			first[nxt] = step
			q.append(nxt)
	return Vector2i.ZERO
