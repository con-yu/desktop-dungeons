class_name Hud
extends Control

## 全部界面绘制与点击命中（自绘 UI，像素风格统一）。

signal level_chosen(index: int)
signal class_chosen(class_id: String)
signal item_clicked(item_id: String)
signal skill_clicked
signal shop_buy(index: int)
signal shop_close
signal next_level
signal retry_level
signal to_title

var state: DungeonState
var screen := "title"
var message := ""
var stats := {}

var _hot: Dictionary = {}
var _hover := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	if screen == "play" or screen == "shop":
		queue_redraw()


## 命中检测：由 Main 用 _unhandled_input 调用，坐标是视口坐标。
func hit_test(pos: Vector2) -> String:
	for key in _hot.keys():
		var r: Rect2 = _hot[key]
		if r.has_point(pos):
			return key
	return ""


func trigger(key: String) -> void:
	_emit(key)


func _emit(key: String) -> void:
	if key == "skill":
		skill_clicked.emit()
	elif key.begins_with("item:"):
		item_clicked.emit(key.substr(5))
	elif key.begins_with("buy:"):
		shop_buy.emit(int(key.substr(4)))
	elif key == "shop_close":
		shop_close.emit()
	elif key.begins_with("level:"):
		level_chosen.emit(int(key.substr(6)))
	elif key.begins_with("class:"):
		class_chosen.emit(key.substr(6))
	elif key == "next":
		next_level.emit()
	elif key == "retry":
		retry_level.emit()
	elif key == "title":
		to_title.emit()
	elif key == "shop_ring":
		shop_close.emit()


# ---------------------------------------------------------------- 绘制入口

func _draw() -> void:
	_hot.clear()
	match screen:
		"title":
			_draw_title()
		"class":
			_draw_class_select()
		"play":
			_draw_game()
		"shop":
			_draw_game()
			_draw_shop()
		"win":
			_draw_game()
			_draw_result(true)
		"lose":
			_draw_game()
			_draw_result(false)


# ---------------------------------------------------------------- 基础绘制

func _panel(r: Rect2, bg := GameConfig.COL_PANEL_BG, edge := GameConfig.COL_PANEL_EDGE) -> void:
	draw_rect(r, bg)
	draw_rect(r, edge, false, 2.0)


func _txt(pos: Vector2, s: String, size := 14, col := GameConfig.COL_TEXT) -> void:
	draw_string(Art.font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_b(pos: Vector2, s: String, size := 14, col := GameConfig.COL_TEXT) -> void:
	draw_string(Art.font_bold, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_cb(r: Rect2, s: String, size := 14, col := GameConfig.COL_TEXT) -> void:
	var w := Art.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := r.position.x + (r.size.x - w) * 0.5
	var y := r.position.y + r.size.y * 0.5 + size * 0.36
	draw_string(Art.font_bold, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_r(right_x: float, y: float, s: String, size := 14, col := GameConfig.COL_TEXT) -> void:
	var w := Art.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(Art.font, Vector2(right_x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_c(r: Rect2, s: String, size := 14, col := GameConfig.COL_TEXT) -> void:
	var w := Art.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := r.position.x + (r.size.x - w) * 0.5
	var y := r.position.y + r.size.y * 0.5 + size * 0.36
	draw_string(Art.font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _wrap(pos: Vector2, s: String, width: float, size := 13, col := GameConfig.COL_DIM, line_h := 18.0) -> void:
	var cursor := pos
	var line := ""
	for ch in s:
		var test := line + ch
		if Art.font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			draw_string(Art.font, cursor, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			cursor.y += line_h
			line = ch
		else:
			line = test
	if line != "":
		draw_string(Art.font, cursor, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color("#0b0d12"))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * clampf(ratio, 0.0, 1.0), r.size.y - 2)), col)
	draw_rect(r, Color(0, 0, 0, 0.65), false, 1.0)


func _btn(key: String, r: Rect2, label: String, enabled := true, accent := Color("#333a47"), font_size := 15) -> void:
	if enabled:
		_hot[key] = r
	var hovered := enabled and r.has_point(get_local_mouse_position())
	var bg := accent
	if not enabled:
		bg = Color("#1d2129")
	elif hovered:
		bg = accent.lightened(0.16)
	draw_rect(r, bg)
	draw_rect(r, Color("#79839a") if enabled else Color("#343a45"), false, 2.0)
	if hovered:
		draw_rect(r.grow(1), Color(1, 1, 1, 0.12), false, 1.0)
	_txt_c(r, label, font_size, Color("#eae6d8") if enabled else Color("#666c78"))


# ---------------------------------------------------------------- 标题 / 选关

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), GameConfig.COL_BG)
	for i in 10:
		var a := 0.03 + i * 0.004
		draw_rect(Rect2(0, 720 - i * 26, 1280, 26), Color(1, 1, 1, a * 0.5))
	_txt_cb(Rect2(0, 62, 1280, 60), "地 牢 远 征", 44, Color("#e8dfc4"))
	_txt_c(Rect2(0, 118, 1280, 26), "单屏地牢 · 探索回血 · 撞击战斗", 15, GameConfig.COL_DIM)

	_txt(Vector2(96, 186), "选择关卡", 18, Color("#b9b29b"))
	_txt_r(1184, 186, "已通关 %d / 10" % DB.progress.get("cleared", []).size(), 14, GameConfig.COL_DIM)

	for i in DB.levels.size():
		var col := i % 5
		var row := i / 5
		var r := Rect2(96 + col * 220, 204 + row * 108, 204, 92)
		var unlocked := DB.is_unlocked(i)
		var cleared: Array = DB.progress.get("cleared", [])
		var ld: Dictionary = DB.levels[i]
		_btn("level:%d" % i, r, "", unlocked)
		draw_rect(r, Color(0, 0, 0, 0.0))
		if unlocked:
			_txt(Vector2(r.position.x + 14, r.position.y + 26), "第 %d 关" % (i + 1), 13, Color("#9aa0ad"))
			_txt_b(Vector2(r.position.x + 14, r.position.y + 50), String(ld.get("name", "")), 20, Color("#ede5cb"))
			var sub := String(ld.get("sub", ""))
			draw_string(Art.font, Vector2(r.position.x + 14, r.position.y + 74), sub.substr(0, 12), HORIZONTAL_ALIGNMENT_LEFT, 180, 12, Color("#8b8778"))
			if cleared.has(i):
				_txt_r(r.position.x + r.size.x - 12, r.position.y + 26, "已通关", 12, Color("#7bbf7b"))
		else:
			_txt_c(r, "未 解 锁", 16, Color("#5a6070"))

	_txt_c(Rect2(0, 470, 1280, 24), "WASD / 方向键 移动并攻击 · Q 技能 · E 用药 · 空格 待机 · R 重开 · Esc 返回", 14, GameConfig.COL_DIM)
	_txt_c(Rect2(0, 506, 1280, 24), "踏入未探索区域会回复生命与法力——那是你唯一的补给来源。", 15, Color("#a8a08a"))


# ---------------------------------------------------------------- 选职业

func _draw_class_select() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), GameConfig.COL_BG)
	var ld: Dictionary = DB.level_def(int(stats.get("level_index", 0)))
	_txt_cb(Rect2(0, 54, 1280, 30), "第 %d 关 · %s" % [int(stats.get("level_index", 0)) + 1, ld.get("name", "")], 24, Color("#e8dfc4"))
	_txt_c(Rect2(0, 92, 1280, 24), "选择你的职业", 15, GameConfig.COL_DIM)

	var ids := ["fighter", "wizard", "rogue"]
	for i in ids.size():
		var cid: String = ids[i]
		var c := DB.class_def(cid)
		var r := Rect2(190 + i * 300, 148, 280, 400)
		_btn("class:" + cid, r, "", true, Color("#232833"))
		var accent := Color(String(c.get("color", "#888888")))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), accent)
		draw_rect(Rect2(r.position + Vector2(10, 16), Vector2(r.size.x - 20, 120)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(r.position + Vector2(10, 16), Vector2(r.size.x - 20, 120)), Color(accent.r, accent.g, accent.b, 0.10))
		var face := Art.char_tex(cid, "south")
		if face != null:
			var scale := 3.0
			var sz := face.get_size() * scale
			draw_texture_rect(face, Rect2(r.position.x + r.size.x * 0.5 - sz.x * 0.5, r.position.y + 20, sz.x, sz.y), false)
		_txt_b(Vector2(r.position.x + 18, r.position.y + 168), String(c.get("name", "")), 26, accent)
		_txt(Vector2(r.position.x + 18, r.position.y + 192), String(c.get("tag", "")), 13, Color("#9aa0ad"))
		_txt(Vector2(r.position.x + 18, r.position.y + 226), "生命 %d   法力 %d" % [int(c.get("hp", 0)), int(c.get("mp", 0))], 14, Color("#cfc9b6"))
		_txt(Vector2(r.position.x + 18, r.position.y + 248), "攻击 %d   防御 %d" % [int(c.get("atk", 0)), int(c.get("def", 0))], 14, Color("#cfc9b6"))
		draw_rect(Rect2(r.position.x + 18, r.position.y + 264, r.size.x - 36, 1), Color(1, 1, 1, 0.1))
		_txt(Vector2(r.position.x + 18, r.position.y + 288), "技能 · %s（%d MP）" % [c.get("skill_name", ""), int(c.get("skill_cost", 0))], 14, accent.lightened(0.2))
		_wrap(Vector2(r.position.x + 18, r.position.y + 310), String(c.get("desc", "")), r.size.x - 36, 13, Color("#9a947f"), 19)
		_txt_c(Rect2(r.position.x, r.position.y + r.size.y - 34, r.size.x, 26), "选择", 15, Color("#eae6d8"))

	_btn("title", Rect2(40, 616, 120, 40), "返回", true, Color("#2a2f3a"))


# ---------------------------------------------------------------- 游戏界面

func _draw_game() -> void:
	if state == null:
		return
	# 注意：这里不能铺满屏底色，否则会盖住下层的地牢视图
	var ld := state.level_def
	_txt_b(Vector2(44, 46), "第 %d 关 · %s" % [state.level_index + 1, ld.get("name", "")], 22, Color("#e8dfc4"))
	_txt(Vector2(44, 70), String(ld.get("sub", "")), 13, Color("#8b8778"))
	var gold_txt := "金币 %d" % state.gold
	_txt_r(1236, 46, gold_txt, 16, GameConfig.COL_GOLD)
	var remain := "剩余敌人 %d" % state.alive_monsters()
	_txt_r(1236, 70, remain, 13, Color("#9aa0ad"))

	_draw_panel()
	_draw_log()


func _draw_panel() -> void:
	var p := state.player
	var r := Rect2(GameConfig.PANEL_X, GameConfig.PANEL_Y, GameConfig.PANEL_W, GameConfig.PANEL_H)
	_panel(r)

	var cd := state.class_data
	var accent := Color(String(cd.get("color", "#cccccc")))
	var x := r.position.x + 16
	var y := r.position.y + 18

	_txt_b(Vector2(x, y + 14), String(cd.get("name", "")), 22, accent)
	_txt_r(r.position.x + r.size.x - 16, y + 14, "等级 %d" % p.level, 16, Color("#e8dfc4"))
	y += 30

	# 头像
	var face := Art.char_tex(state.class_id, state.player_facing)
	if face != null:
		draw_texture_rect(face, Rect2(x, y, 64, 64), false)
		draw_rect(Rect2(x, y, 64, 64), Color(1, 1, 1, 0.12), false, 1.0)

	var bx := x + 76
	var bw := r.size.x - 76 - 32
	_txt(Vector2(bx, y + 14), "%d / %d" % [p.hp, p.max_hp], 13, Color("#e0a2a2"))
	_bar(Rect2(bx, y + 20, bw, 12), p.hp_ratio(), GameConfig.COL_HP)
	_txt(Vector2(bx, y + 50), "%d / %d" % [p.mp, p.max_mp], 13, Color("#9db8e0"))
	_bar(Rect2(bx, y + 56, bw, 10), float(p.mp) / float(maxi(p.max_mp, 1)), GameConfig.COL_MP)
	y += 76

	var need := GameConfig.xp_needed(p.level)
	_txt(Vector2(x, y + 14), "经验 %d / %d" % [p.xp, need], 13, Color("#c9b06a"))
	_bar(Rect2(x, y + 20, r.size.x - 32, 8), float(p.xp) / float(maxi(need, 1)), GameConfig.COL_XP)
	y += 42

	_txt(Vector2(x, y), "攻击 %d" % p.atk, 15, Color("#e0c49a"))
	_txt(Vector2(x + 110, y), "防御 %d" % p.defense, 15, Color("#9ec4c4"))
	if p.status.get("poison", 0) > 0:
		_txt(Vector2(x + 220, y), "中毒 %d" % int(p.status["poison"]), 14, Color("#7bc47f"))
	if p.status.get("stealth", 0) > 0:
		_txt(Vector2(x + 220, y), "潜行中", 14, Color("#6fa8d0"))
	y += 16

	draw_rect(Rect2(x, y, r.size.x - 32, 1), Color(1, 1, 1, 0.09))
	y += 14

	# 技能
	var sr := Rect2(x, y, r.size.x - 32, 62)
	_btn("skill", sr, "", p.mp >= int(cd.get("skill_cost", 5)), Color("#242a35"), 15)
	draw_rect(Rect2(sr.position, Vector2(3, sr.size.y)), accent)
	_txt(Vector2(sr.position.x + 12, sr.position.y + 24), "Q · %s" % cd.get("skill_name", ""), 15, Color("#eae6d8"))
	_txt_r(sr.position.x + sr.size.x - 10, sr.position.y + 24, "%d MP" % int(cd.get("skill_cost", 0)), 13, Color("#9db8e0"))
	_wrap(Vector2(sr.position.x + 12, sr.position.y + 44), String(cd.get("skill_desc", "")), sr.size.x - 24, 12, Color("#8b8778"), 16)
	y += 74

	# 道具（两列紧凑网格）
	_txt(Vector2(x, y + 12), "道具（点击使用 · E 快捷用药）", 13, Color("#9aa0ad"))
	y += 22
	if state.items.is_empty():
		_txt(Vector2(x, y + 16), "空空如也", 13, Color("#5f6470"))
	else:
		var i := 0
		var cell_w := (r.size.x - 32 - 8) * 0.5
		for iid in state.items.keys():
			var d := DB.item_def(iid)
			var cx := x + (i % 2) * (cell_w + 8)
			var cy := y + (i / 2) * 46
			var ir := Rect2(cx, cy, cell_w, 42)
			_btn("item:" + String(iid), ir, "", true, Color("#20252e"), 13)
			var icon := Art.item_tex(String(d.get("sprite", iid)))
			if icon != null:
				draw_texture_rect(icon, Rect2(ir.position.x + 4, ir.position.y + 5, 32, 32), false)
			else:
				draw_rect(Rect2(ir.position.x + 4, ir.position.y + 5, 32, 32), accent.darkened(0.3))
			_txt(Vector2(ir.position.x + 40, ir.position.y + 18), clipped(String(d.get("name", iid)), 5), 13, Color("#ded8c6"))
			_txt_r(ir.position.x + ir.size.x - 6, ir.position.y + 18, "x%d" % int(state.items[iid]), 12, GameConfig.COL_DIM)
			i += 1

	# 底部提示
	var hint_y := r.position.y + r.size.y - 42
	draw_rect(Rect2(x, hint_y - 12, r.size.x - 32, 1), Color(1, 1, 1, 0.09))
	_txt(Vector2(x, hint_y + 4), "WASD 移动 / 撞击攻击 · 空格 待机", 12, Color("#6f7480"))
	_txt(Vector2(x, hint_y + 22), "击杀 BOSS 后踏上阶梯过关 · Esc 返回 · R 重开", 12, Color("#6f7480"))


func _draw_log() -> void:
	var r := Rect2(GameConfig.BOARD_X, GameConfig.LOG_Y, 836, 92)
	_panel(r, Color("#101318"), Color("#2a303c"))
	var lines: Array = state.log_lines
	var show_n := mini(4, lines.size())
	for i in show_n:
		var txt := String(lines[lines.size() - show_n + i])
		var col := GameConfig.COL_TEXT if i == show_n - 1 else Color("#7d838f")
		_txt(Vector2(r.position.x + 14, r.position.y + 22 + i * 19), clipped(txt, 56), 13, col)
	_draw_target_panel()


func clipped(s: String, max_chars: int) -> String:
	if s.length() <= max_chars:
		return s
	return s.substr(0, max_chars - 1) + "…"


func _adjacent_target() -> Actor:
	var best: Actor = null
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var m := state.monster_at(state.player.pos + d)
		if m == null:
			continue
		if best == null or (m.is_boss and not best.is_boss):
			best = m
	return best


func _draw_target_panel() -> void:
	var r := Rect2(GameConfig.PANEL_X, GameConfig.LOG_Y, GameConfig.PANEL_W, 92)
	_panel(r, Color("#12161c"), Color("#2a303c"))
	var m := _adjacent_target()
	if m == null:
		_txt(Vector2(r.position.x + 14, r.position.y + 30), "目标：—", 14, Color("#6f7480"))
		_txt(Vector2(r.position.x + 14, r.position.y + 54), "靠近敌人可查看攻防与特性", 12, Color("#565c68"))
		return
	var x := r.position.x + 14
	var prefix := "★ " if m.is_boss else ""
	_txt_b(Vector2(x, r.position.y + 22), prefix + m.display_name, 15, Color("#f0d090") if m.is_boss else Color("#e6e0cf"))
	_txt_r(r.position.x + r.size.x - 14, r.position.y + 22, "%d / %d" % [m.hp, m.max_hp], 12, Color("#e0a2a2"))
	_bar(Rect2(x, r.position.y + 28, r.size.x - 28, 6), m.hp_ratio(), Color("#c4454a"))
	_txt(Vector2(x, r.position.y + 52), "攻击 %d   防御 %d" % [m.atk, m.defense], 13, Color("#cfc9b6"))
	var tags := _trait_tags(m)
	if tags != "":
		_txt(Vector2(x, r.position.y + 74), tags, 12, Color("#93a7bd"))


func _trait_tags(m: Actor) -> String:
	var out: Array = []
	var map := {
		"undead": "亡灵",
		"poison": "剧毒",
		"acid": "酸蚀",
		"regen": "再生",
		"ranged": "远程",
		"lifesteal": "吸血",
		"aggro": "主动",
	}
	for t in m.traits:
		if map.has(t):
			out.append(map[t])
	if m.aggro and not out.has("主动"):
		out.append("主动")
	return " · ".join(out)


# ---------------------------------------------------------------- 商店

func _draw_shop() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))
	var r := Rect2(370, 150, 540, 420)
	_panel(r, Color("#1a1d24"), Color("#6b5a2e"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("#c9a227"))
	_txt_cb(Rect2(r.position.x, r.position.y + 16, r.size.x, 30), "旅行商人", 22, Color("#e8d79a"))
	_txt_c(Rect2(r.position.x, r.position.y + 48, r.size.x, 22), "「钱货两讫，出了这个门我就不认识你。」", 13, Color("#8b8778"))
	_txt_r(r.position.x + r.size.x - 20, r.position.y + 66, "金币 %d" % state.gold, 15, GameConfig.COL_GOLD)

	for i in state.shop_stock.size():
		var entry: Dictionary = state.shop_stock[i]
		var d := DB.item_def(String(entry.id))
		var ir := Rect2(r.position.x + 24, r.position.y + 86 + i * 88, r.size.x - 48, 76)
		_panel(ir, Color("#20242c"), Color("#3a4150"))
		var icon := Art.item_tex(String(d.get("sprite", entry.id)))
		if icon != null:
			draw_texture_rect(icon, Rect2(ir.position.x + 10, ir.position.y + 8, 40, 40), false)
		_txt(Vector2(ir.position.x + 62, ir.position.y + 26), String(d.get("name", "")), 16, Color("#e8e2d0"))
		_wrap(Vector2(ir.position.x + 62, ir.position.y + 46), String(d.get("desc", "")), ir.size.x - 190, 12, Color("#8b8778"), 15)
		var price := int(entry.price)
		var sold := bool(entry.sold)
		var can := state.gold >= price and not sold
		_btn("buy:%d" % i, Rect2(ir.position.x + ir.size.x - 120, ir.position.y + 20, 104, 36), "已售出" if sold else "%d 金" % price, can, Color("#2d3a2c"))

	_btn("shop_close", Rect2(r.position.x + r.size.x * 0.5 - 70, r.position.y + r.size.y - 52, 140, 38), "离开", true, Color("#2a2f3a"))


# ---------------------------------------------------------------- 结算

func _draw_result(win: bool) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	var r := Rect2(400, 190, 480, 320)
	_panel(r, Color("#14171d"), Color("#6b5a2e") if win else Color("#5a2c2c"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("#c9a227") if win else Color("#a33a3a"))
	_txt_cb(Rect2(r.position.x, r.position.y + 26, r.size.x, 40), "关 卡 通 过" if win else "你 倒 下 了", 30, Color("#f0e2b0") if win else Color("#e08a8a"))
	var p := state.player
	var lines := [
		"职业：%s　等级 %d" % [state.class_data.get("name", ""), p.level],
		"击杀敌人：%d　剩余敌人：%d" % [int(stats.get("kills", 0)), state.alive_monsters()],
		"金币：%d　回合：%d" % [state.gold, state.turn],
	]
	for i in lines.size():
		_txt_c(Rect2(r.position.x, r.position.y + 92 + i * 26, r.size.x, 24), String(lines[i]), 14, Color("#b9b29b"))

	if win:
		_btn("next", Rect2(r.position.x + 60, r.position.y + r.size.y - 76, 160, 44), "下一关", true, Color("#2b3a2c"))
		_btn("title", Rect2(r.position.x + 260, r.position.y + r.size.y - 76, 160, 44), "返回标题", true, Color("#2a2f3a"))
	else:
		_btn("retry", Rect2(r.position.x + 60, r.position.y + r.size.y - 76, 160, 44), "重试本关", true, Color("#3a2c2c"))
		_btn("title", Rect2(r.position.x + 260, r.position.y + r.size.y - 76, 160, 44), "返回标题", true, Color("#2a2f3a"))
