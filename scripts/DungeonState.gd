class_name DungeonState
extends RefCounted

## 一局地牢的全部状态与规则运算。渲染与输入都在 Main 里，这里只管规则。

const W := GameConfig.GRID_W
const H := GameConfig.GRID_H

var level_index := 0
var level_def: Dictionary = {}
var theme: Dictionary = {}

var tiles := PackedByteArray()
var explored := PackedByteArray()
var visible := PackedByteArray()
var props: Dictionary = {}          # Vector2i -> "shop" / "stairs"

var monsters: Array[Actor] = []            # Array[Actor]
var player: Actor
var boss: Actor = null

var rng := RandomNumberGenerator.new()
var turn := 0
var boss_dead := false
var player_dead := false
var victory := false

var log_lines: Array = []
var fx_list: Array = []             # {"pos":Vector2i, "text":String, "color":Color, "t":float}
var mp_frac := 0.0

var class_id := "fighter"
var class_data: Dictionary = {}
var items: Dictionary = {}          # item_id -> count
var gold := 0
var kills := 0
var shop_stock: Array = []          # [{"id":String,"price":int,"sold":bool}]
var shop_pos := Vector2i(-1, -1)
var player_facing := "south"
var _acid_stacks := 0


# ---------------------------------------------------------------- 开局

func new_run(index: int, cid: String, seed_value := 0) -> void:
	level_index = index
	level_def = DB.level_def(index).duplicate(true)
	class_id = cid
	class_data = DB.class_def(cid)
	tiles = PackedByteArray()
	explored = PackedByteArray()
	visible = PackedByteArray()
	explored.resize(W * H)
	visible.resize(W * H)
	props.clear()
	monsters.clear()
	log_lines.clear()
	fx_list.clear()
	mp_frac = 0.0
	turn = 0
	_acid_stacks = 0
	boss_dead = false
	player_dead = false
	victory = false
	shop_stock.clear()
	shop_pos = Vector2i(-1, -1)

	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var gen := LevelGen.generate(level_def, rng)
	tiles = gen.tiles

	player = _make_player(gen.start)
	_spawn_monsters(gen)
	_setup_shop(gen)

	items.clear()
	var start_items: Dictionary = level_def.get("start_items", {})
	for k in start_items.keys():
		items[k] = int(start_items[k])
	gold = int(level_def.get("start_gold", 0))

	visible.fill(0)
	reveal_around(player.pos, GameConfig.EXPLORE_CLAIRVOYANCE)
	add_log("进入「%s」。%s" % [level_def.get("name", "地牢"), level_def.get("sub", "")])


func _make_player(pos: Vector2i) -> Actor:
	var p := Actor.new()
	p.is_player = true
	p.def_id = class_id
	p.display_name = class_data.get("name", "冒险者")
	p.pos = pos
	p.max_hp = int(class_data.get("hp", 50))
	p.hp = p.max_hp
	p.max_mp = int(class_data.get("mp", 10))
	p.mp = p.max_mp
	p.atk = int(class_data.get("atk", 6))
	p.defense = int(class_data.get("def", 2))
	p.color = class_data.get("color", "#cccccc")
	p.sprite = class_id
	return p


func _spawn_monsters(gen: Dictionary) -> void:
	var power := float(level_def.get("power", 1.0))

	# 按距离分三个环带：近带放杂兵，中带放中坚，远带放精英，形成推进式难度梯度
	var buckets := {"near": [], "mid": [], "far": []}
	for c in gen.slots:
		var d := _manhattan(c, player.pos)
		if d <= 8:
			buckets["near"].append(c)
		elif d <= 15:
			buckets["mid"].append(c)
		else:
			buckets["far"].append(c)
	for k in buckets.keys():
		_shuffle(buckets[k])

	var queue: Array = []
	for entry in level_def.get("monsters", []):
		var count := int(entry.get("count", 1))
		for i in count:
			queue.append(String(entry.get("id", "rat")))
	queue.sort_custom(func(a, b): return _spawn_order(String(a)) < _spawn_order(String(b)))

	var placed: Array = []
	for id in queue:
		var tier := _tier_of(String(id))
		var order: Array = ["near", "mid", "far"]
		if tier == 2:
			order = ["mid", "near", "far"]
		elif tier >= 3:
			order = ["far", "mid", "near"]
		var spot := _take_slot(buckets, order, placed)
		if spot.x < 0:
			continue
		var m := _make_monster(String(id), power)
		m.pos = spot
		placed.append(spot)
		monsters.append(m)

	var bdef: Dictionary = level_def.get("boss", {})
	if not bdef.is_empty():
		var b := _make_monster(String(bdef.get("id", "rat")), power)
		b.display_name = String(bdef.get("name", b.display_name))
		b.max_hp = int(round(b.max_hp * float(bdef.get("hp_mul", 1.0))))
		b.hp = b.max_hp
		b.atk = int(round(b.atk * float(bdef.get("atk_mul", 1.0))))
		b.defense += int(bdef.get("def_add", 0))
		b.xp_value = int(round(b.xp_value * float(bdef.get("xp_mul", 1.0))))
		b.gold_value = int(bdef.get("gold", 20))
		b.is_boss = true
		b.pos = gen.boss_pos
		boss = b
		monsters.append(b)


func _make_monster(id: String, power: float) -> Actor:
	var d := DB.monster_def(id)
	var m := Actor.new()
	m.def_id = id
	m.display_name = d.get("name", id)
	# 关卡强度只重点放大血量，攻击与防御放缓，避免高关卡出现"打不动"的墙
	var ramp := power - 1.0
	m.max_hp = int(round(float(d.get("hp", 5)) * power))
	m.hp = m.max_hp
	m.atk = int(round(float(d.get("atk", 2)) * (1.0 + ramp * 0.38)))
	m.defense = int(round(float(d.get("def", 0)) * (1.0 + ramp * 0.25)))
	m.xp_value = int(round(float(d.get("xp", 2)) * (0.9 + power * 0.1)))
	m.gold_value = int(d.get("gold", 1))
	m.traits = (d.get("traits", []) as Array).duplicate()
	m.aggro = bool(d.get("aggro", false)) or m.traits.has("aggro")
	m.sprite = d.get("sprite", id)
	var h: int = absi(hash(id))
	m.color = Color.from_hsv(float(h % 997) / 997.0, 0.45, 0.8).to_html(false)
	return m


func _setup_shop(gen: Dictionary) -> void:
	if not bool(level_def.get("shop", false)):
		return
	var slots: Array = gen.slots
	for i in range(slots.size() - 1, max(slots.size() - 24, 0), -1):
		var c: Vector2i = slots[i]
		if _manhattan(c, player.pos) >= 6:
			shop_pos = c
			props[c] = "shop"
			break
	if shop_pos.x < 0 and slots.size() > 10:
		shop_pos = slots[slots.size() - 1]
		props[shop_pos] = "shop"

	var pool: Array = DB.items.keys()
	pool.shuffle()
	for i in mini(3, pool.size()):
		var iid: String = pool[i]
		shop_stock.append({
			"id": iid,
			"price": int(DB.item_def(iid).get("price", 15)),
			"sold": false,
		})


# ---------------------------------------------------------------- 查询

func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func is_wall(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	return tiles[idx(c)] == LevelGen.WALL


func is_explored(c: Vector2i) -> bool:
	return in_bounds(c) and explored[idx(c)] == 1


func is_visible(c: Vector2i) -> bool:
	return in_bounds(c) and visible[idx(c)] == 1


func monster_at(c: Vector2i) -> Actor:
	for m in monsters:
		if m.is_alive() and m.pos == c:
			return m
	return null


func actor_at(c: Vector2i) -> Actor:
	for m in monsters:
		if m.is_alive() and m.pos == c:
			return m
	if player.is_alive() and player.pos == c:
		return player
	return null


func alive_monsters() -> int:
	var n := 0
	for m in monsters:
		if m.is_alive():
			n += 1
	return n


# ---------------------------------------------------------------- 视线与探索

func reveal_around(center: Vector2i, radius: int) -> int:
	var gained := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if not in_bounds(c):
				continue
			if is_wall(c) and c != center:
				# 墙也要揭示，否则地牢轮廓是黑的
				if explored[idx(c)] == 0:
					explored[idx(c)] = 1
					gained += 1
				continue
			if explored[idx(c)] == 0:
				explored[idx(c)] = 1
				gained += 1
	visible.fill(0)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if in_bounds(c):
				visible[idx(c)] = 1
	return gained


# ---------------------------------------------------------------- 玩家行动

func player_action(kind: String, dir := Vector2i.ZERO) -> bool:
	if player_dead or victory:
		return false
	var acted := false
	match kind:
		"move":
			acted = _do_move(dir)
		"wait":
			add_log("你原地戒备。")
			acted = true
		"skill":
			acted = _do_skill()
		_:
			acted = false
	if acted:
		_after_player_action()
	return acted


func _do_move(dir: Vector2i) -> bool:
	var target := player.pos + dir
	if dir.x < 0:
		player_facing = "west"
	elif dir.x > 0:
		player_facing = "east"
	elif dir.y < 0:
		player_facing = "north"
	elif dir.y > 0:
		player_facing = "south"
	if is_wall(target):
		return false
	var m := monster_at(target)
	if m != null:
		_player_attack(m, 1.0, false)
		return true

	var fresh := explored[idx(target)] == 0
	player.pos = target
	var new_cells := reveal_around(target, GameConfig.EXPLORE_CLAIRVOYANCE)
	if new_cells > 0:
		var hp_before := player.hp
		player.hp = mini(player.hp + new_cells, player.max_hp)
		if player.hp > hp_before:
			_push_fx(target, "+%d" % (player.hp - hp_before), Color("#6fbf73"))
		mp_frac += new_cells * 0.7
		var mp_gain := int(floor(mp_frac))
		if mp_gain > 0:
			mp_frac -= mp_gain
			player.mp = mini(player.mp + mp_gain, player.max_mp)
	if fresh:
		Sfx.play("step", randf_range(0.94, 1.06), -12.0)

	_on_cell_entered()
	return true


func _on_cell_entered() -> void:
	if props.get(player.pos, "") == "stairs":
		victory = true
		add_log("你踏入地牢深处，这一层被清空了！")
		Sfx.play("victory")


# ---------------------------------------------------------------- 战斗

func _phys_damage(atk: int, defense: int, traits: Array, mult: float) -> int:
	var base := maxi(1, atk - defense)
	var dmg := int(round(base * mult))
	if traits.has("undead"):
		dmg = maxi(1, int(round(dmg * 0.7)))
	return maxi(1, dmg)


func _magic_damage(power: int, defense: int, traits: Array) -> int:
	var dmg := maxi(1, power - int(defense * 0.5))
	if traits.has("undead"):
		dmg = int(round(dmg * 1.3))
	return maxi(1, dmg)


func _player_attack(m: Actor, mult: float, no_counter: bool) -> void:
	var stealth: bool = int(player.status.get("stealth", 0)) > 0
	var use_mult := mult * (3.0 if stealth else 1.0)
	var dmg := _phys_damage(player.atk, m.defense, m.traits, use_mult)
	m.hp -= dmg
	m.flash = 0.2
	_push_fx(m.pos, "-%d" % dmg, Color("#ffd166"))
	Sfx.play("hit", randf_range(0.95, 1.08))
	if stealth:
		player.status.erase("stealth")
		m.stunned = 1
		add_log("潜行突袭！对 %s 造成 %d 伤害。" % [m.display_name, dmg])
	else:
		add_log("你攻击 %s，造成 %d 伤害。" % [m.display_name, dmg])

	if m.hp <= 0:
		_kill_monster(m)
		return
	if no_counter:
		# 猛击/潜行的额外效果：目标被打断，本回合无法行动
		m.stunned = 1


func _monster_attack(m: Actor) -> void:
	var dmg := maxi(1, m.atk - player.defense)
	player.hp -= dmg
	_push_fx(player.pos, "-%d" % dmg, Color("#ff6b6b"))
	Sfx.play("hurt", randf_range(0.92, 1.05))
	add_log("%s 攻击你，造成 %d 伤害。" % [m.display_name, dmg])
	if m.has_trait("poison"):
		player.status["poison"] = 4
		add_log("你中毒了。")
	if m.has_trait("acid") and _acid_stacks < 3:
		_acid_stacks += 1
		player.defense = maxi(0, player.defense - 1)
		add_log("酸液腐蚀了你的护甲（防御 -1）。")
	if m.has_trait("lifesteal"):
		var heal := int(round(dmg * 0.5))
		m.hp = mini(m.max_hp, m.hp + heal)
		_push_fx(m.pos, "+%d" % heal, Color("#a35bd1"))
	if player.hp <= 0:
		player.hp = 0
		player.dead = true
		player_dead = true
		add_log("你倒下了……")
		Sfx.play("death")


func _kill_monster(m: Actor) -> void:
	m.dead = true
	m.hp = 0
	kills += 1
	gold += m.gold_value
	_push_fx(m.pos, "+%d" % m.gold_value + "金", Color("#d4af37"))
	add_log("击杀 %s（+%d 经验，+%d 金币）。" % [m.display_name, m.xp_value, m.gold_value])
	Sfx.play("kill")
	_gain_xp(m.xp_value)
	# 战士「战意」：每两次击杀永久 +1 攻击
	if class_id == "fighter" and kills % 2 == 0:
		player.atk += 1
	if m.is_boss:
		boss_dead = true
		props[m.pos] = "stairs"
		add_log("「%s」倒下了！通往下一层的阶梯浮现。" % m.display_name)
		Sfx.play("boss_down")


func _gain_xp(amount: int) -> void:
	player.xp += amount
	while player.level < 15 and player.xp >= GameConfig.xp_needed(player.level):
		player.xp -= GameConfig.xp_needed(player.level)
		player.level += 1
		player.max_hp += int(class_data.get("hp_growth", 10))
		player.max_mp += int(class_data.get("mp_growth", 2))
		player.atk += int(class_data.get("atk_growth", 2))
		player.defense += int(class_data.get("def_growth", 1))
		player.hp = player.max_hp
		player.mp = player.max_mp
		add_log("升级！等级 %d —— 生命与法力全满。" % player.level)
		_push_fx(player.pos, "LEVEL UP", Color("#ffe066"))
		Sfx.play("levelup")


# ---------------------------------------------------------------- 技能

func _adjacent_monster() -> Actor:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var m := monster_at(player.pos + d)
		if m != null:
			return m
	return null


func _nearest_monster(max_dist: int) -> Actor:
	var best: Actor = null
	var best_d := 999
	for m in monsters:
		if not m.is_alive():
			continue
		var d := _manhattan(m.pos, player.pos)
		if d <= max_dist and d < best_d and is_explored(m.pos):
			best = m
			best_d = d
	return best


func _do_skill() -> bool:
	var cost := int(class_data.get("skill_cost", 5))
	var skill := String(class_data.get("skill_id", ""))
	if player.mp < cost:
		add_log("法力不足（需要 %d MP）。" % cost)
		return false

	match skill:
		"smash":
			var m := _adjacent_monster()
			if m == null:
				add_log("身边没有敌人。")
				return false
			player.mp -= cost
			add_log("猛击！")
			Sfx.play("hit", 0.85)
			_player_attack(m, 1.8, true)
			return true
		"fireball":
			var m := _nearest_monster(3)
			if m == null:
				add_log("3 格内没有可见敌人。")
				return false
			player.mp -= cost
			var power := 12 + player.level * 3
			var dmg := _magic_damage(power, m.defense, m.traits)
			m.hp -= dmg
			m.flash = 0.2
			_push_fx(m.pos, "-%d" % dmg, Color("#ff8f3f"))
			add_log("火球术！对 %s 造成 %d 法术伤害。" % [m.display_name, dmg])
			Sfx.play("fireball")
			if m.hp <= 0:
				_kill_monster(m)
			return true
		"stealth":
			player.mp -= cost
			player.status["stealth"] = 1
			add_log("你隐入阴影，下一次攻击威力大增。")
			Sfx.play("stealth")
			return true
	return false


# ---------------------------------------------------------------- 怪物回合

func _after_player_action() -> void:
	turn += 1
	_tick_player_status()
	if player_dead:
		return
	_monsters_act()
	if player_dead:
		return
	visible.fill(0)
	var r := GameConfig.EXPLORE_CLAIRVOYANCE
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := player.pos + Vector2i(dx, dy)
			if in_bounds(c):
				visible[idx(c)] = 1


func _tick_player_status() -> void:
	var poison := int(player.status.get("poison", 0))
	if poison > 0:
		var dmg := 3
		player.hp -= dmg
		_push_fx(player.pos, "-%d" % dmg, Color("#7bc47f"))
		add_log("毒素发作，损失 %d 生命。" % dmg)
		player.status["poison"] = poison - 1
		if player.status["poison"] <= 0:
			player.status.erase("poison")
		if player.hp <= 0:
			player.hp = 0
			player_dead = true
			player.dead = true


func _monsters_act() -> void:
	for m in monsters:
		if not m.is_alive() or player_dead:
			continue
		if m.stunned > 0:
			m.stunned -= 1
			continue
		if m.has_trait("regen") and m.hp < m.max_hp:
			m.hp = mini(m.max_hp, m.hp + 2)
		var d := m.pos - player.pos
		var dist := absi(d.x) + absi(d.y)
		if dist == 1:
			_monster_attack(m)
		elif m.has_trait("ranged") and dist <= 3 and (d.x == 0 or d.y == 0):
			var dmg := maxi(1, m.atk - player.defense - 1)
			player.hp -= dmg
			_push_fx(player.pos, "-%d" % dmg, Color("#ff9f6b"))
			add_log("%s 远程射击，造成 %d 伤害。" % [m.display_name, dmg])
			Sfx.play("arrow")
			if player.hp <= 0:
				player.hp = 0
				player_dead = true
				player.dead = true
		elif m.aggro and dist <= 4:
			_step_toward(m, d)


func _step_toward(m: Actor, delta: Vector2i) -> void:
	var options: Array = []
	if absi(delta.x) >= absi(delta.y):
		options.append(Vector2i(signi(delta.x), 0))
		options.append(Vector2i(0, signi(delta.y)))
	else:
		options.append(Vector2i(0, signi(delta.y)))
		options.append(Vector2i(signi(delta.x), 0))
	if randf() < 0.5:
		options.reverse()
	for d in options:
		if d == Vector2i.ZERO:
			continue
		var t: Vector2i = m.pos + d
		if is_wall(t) or actor_at(t) != null:
			continue
		m.pos = t
		return


# ---------------------------------------------------------------- 道具与商店

func use_item(item_id: String) -> bool:
	if not items.has(item_id) or int(items[item_id]) <= 0:
		add_log("没有这个道具。")
		return false
	var d := DB.item_def(item_id)
	items[item_id] = int(items[item_id]) - 1
	if int(items[item_id]) <= 0:
		items.erase(item_id)

	match String(d.get("type", "potion")):
		"potion":
			if d.has("heal_pct"):
				var heal := int(round(player.max_hp * float(d.heal_pct) / 100.0))
				var before := player.hp
				player.hp = mini(player.max_hp, player.hp + heal)
				add_log("饮下%s，回复 %d 生命。" % [d.get("name", "药水"), player.hp - before])
				_push_fx(player.pos, "+%d" % (player.hp - before), Color("#6fbf73"))
			if d.has("mana_pct"):
				var gain := int(round(player.max_mp * float(d.mana_pct) / 100.0))
				var before_mp := player.mp
				player.mp = mini(player.max_mp, player.mp + gain)
				add_log("饮下%s，回复 %d 法力。" % [d.get("name", "药水"), player.mp - before_mp])
			if d.has("xp"):
				add_log("获得 %d 经验。" % int(d.xp))
				_gain_xp(int(d.xp))
			Sfx.play("potion")
		"perm":
			player.atk += int(d.get("atk", 0))
			player.defense += int(d.get("def", 0))
			add_log("药力融入身体（攻击 +%d，防御 +%d）。" % [int(d.get("atk", 0)), int(d.get("def", 0))])
			Sfx.play("potion")
		"scroll":
			var m := _nearest_monster(3)
			if m == null:
				items[item_id] = int(items.get(item_id, 0)) + 1
				add_log("3 格内没有可见敌人，卷轴未使用。")
				return false
			var dmg := int(d.get("damage", 20))
			m.hp -= dmg
			m.flash = 0.25
			_push_fx(m.pos, "-%d" % dmg, Color("#ff8f3f"))
			add_log("%s 灼烧 %s，造成 %d 伤害。" % [d.get("name", "卷轴"), m.display_name, dmg])
			Sfx.play("fireball")
			if m.hp <= 0:
				_kill_monster(m)
	_after_player_action()
	return true


func buy(index: int) -> bool:
	if index < 0 or index >= shop_stock.size():
		return false
	var entry: Dictionary = shop_stock[index]
	if bool(entry.sold):
		return false
	var price := int(entry.price)
	if gold < price:
		add_log("金币不足。")
		return false
	gold -= price
	entry.sold = true
	shop_stock[index] = entry
	var iid := String(entry.id)
	items[iid] = int(items.get(iid, 0)) + 1
	add_log("购买 %s（-%d 金币）。" % [DB.item_def(iid).get("name", iid), price])
	Sfx.play("coin")
	return true


# ---------------------------------------------------------------- 工具

func add_log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 40:
		log_lines = log_lines.slice(log_lines.size() - 40)


func _push_fx(pos: Vector2i, text: String, color: Color) -> void:
	fx_list.append({"pos": pos, "text": text, "color": color, "t": 0.0})


func tick_fx(delta: float) -> void:
	for f in fx_list:
		f.t += delta
	fx_list = fx_list.filter(func(f): return f.t < 1.0)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _tier_of(id: String) -> int:
	return int(DB.monster_def(id).get("tier", 1))


## 依次尝试环带，挑一个与已有怪物保持间距的格子。
func _take_slot(buckets: Dictionary, order: Array, placed: Array) -> Vector2i:
	for key in order:
		var arr: Array = buckets[key]
		var idx := arr.size() - 1
		while idx >= 0:
			var c: Vector2i = arr[idx]
			arr.remove_at(idx)
			var ok := true
			for p in placed:
				if _manhattan(c, p) < 2:
					ok = false
					break
			if ok:
				return c
			idx -= 1
	return Vector2i(-1, -1)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 生成排序：低阶在前；同阶里"不主动追击"的排更前，避免开局就被怪群围杀。
func _spawn_order(id: String) -> int:
	var d := DB.monster_def(id)
	var order := _tier_of(id) * 10
	var traits: Array = d.get("traits", [])
	if bool(d.get("aggro", false)) or traits.has("aggro"):
		order += 5
	return order
