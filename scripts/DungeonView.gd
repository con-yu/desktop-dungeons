class_name DungeonView
extends Node2D

## 静态层：地砖、未探索迷雾、已探索遮罩、道具格。

const FLOOR_REGION := Rect2(64, 64, 32, 32)
const WALL_REGION := Rect2(0, 192, 32, 32)

var state: DungeonState

var sheet: Texture2D
var has_sheet := false
var theme_bg := Color("#0f1218")
var theme_floor := Color("#3b3f4a")
var theme_wall := Color("#575043")
var tile_tint := Color("#ffffff")

var entity_root: Node2D
var overlay: OverlayView
var _nodes: Dictionary = {}
var _shadow_tex: Texture2D


func _ready() -> void:
	entity_root = Node2D.new()
	entity_root.name = "Entities"
	add_child(entity_root)
	overlay = OverlayView.new()
	overlay.name = "Overlay"
	overlay.view = self
	add_child(overlay)
	_shadow_tex = Art.shadow_tex()


func setup(s: DungeonState) -> void:
	state = s
	var ld := s.level_def
	theme_bg = Color(String(ld.get("bg", "#0f1218")))
	theme_floor = Color(String(ld.get("floor", "#3b3f4a")))
	theme_wall = Color(String(ld.get("wall", "#575043")))
	tile_tint = Color(String(ld.get("tint", "#ffffff")))

	var t := Art.tex("res://assets/tiles/dungeon.png")
	sheet = t
	has_sheet = t != null

	for k in _nodes.keys():
		if is_instance_valid(_nodes[k]):
			_nodes[k].queue_free()
	_nodes.clear()
	for c in entity_root.get_children():
		c.queue_free()

	overlay.state = s
	_sync_entities(0.0)
	queue_redraw()


func refresh() -> void:
	queue_redraw()
	if overlay:
		overlay.queue_redraw()


func _process(delta: float) -> void:
	if state == null:
		return
	_sync_entities(delta)
	if overlay:
		overlay.queue_redraw()


func _sync_entities(delta: float) -> void:
	# 怪物
	var alive := {}
	for m in state.monsters:
		if not m.is_alive():
			continue
		alive[m] = true
		var node: Sprite2D = _nodes.get(m)
		if node == null:
			node = _make_entity_node(m, false)
			_nodes[m] = node
		node.visible = state.is_explored(m.pos)
		var base := GameConfig.cell_center(m.pos)
		m.bob_seed += delta
		var bob: float = sin(m.bob_seed * 2.2) * 0.9 if not m.is_boss else sin(m.bob_seed * 1.5) * 1.4
		node.position = Vector2(round(base.x), round(base.y - 2 + bob))
		node.modulate = _entity_modulate(m)
	for key in _nodes.keys():
		if not alive.has(key):
			if is_instance_valid(_nodes[key]):
				_nodes[key].queue_free()
			_nodes.erase(key)

	# 玩家
	var p := state.player
	if p == null:
		return
	if not _nodes.has("player"):
		_nodes["player"] = _make_entity_node(p, true)
	var pn: Sprite2D = _nodes["player"]
	pn.visible = true
	var pc := GameConfig.cell_center(p.pos)
	pn.position = Vector2(round(pc.x), round(pc.y - 3 + sin(p.bob_seed * 3.0) * 0.6))
	pn.modulate = Color(1, 1, 1, 1) if state.player_dead == false else Color(0.5, 0.2, 0.2, 0.9)
	var want := Art.char_tex(state.class_id, state.player_facing)
	if pn.texture != want and want != null:
		pn.texture = want


func _entity_modulate(m: Actor) -> Color:
	var col := Color(1, 1, 1, 1)
	if m.flash > 0.0:
		col = Color(2.2, 2.2, 2.0, 1)
	elif not state.is_visible(m.pos):
		col = Color(0.62, 0.62, 0.7, 1)
	if m.is_boss:
		col = Color(col.r * 1.05, col.g * 1.0, col.b * 0.92, col.a)
	return col


func _make_entity_node(a: Actor, is_player: bool) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = null
	if is_player:
		tex = Art.char_tex(state.class_id, "south")
		if tex == null:
			tex = Art.placeholder(Color(a.color), "P")
	else:
		tex = Art.monster_tex(a.sprite)
		if tex == null:
			tex = Art.placeholder(Color(a.color), a.display_name.substr(0, 1))
	s.texture = tex
	if a.is_boss:
		s.scale = Vector2(1.28, 1.28)
	entity_root.add_child(s)

	var shadow := Sprite2D.new()
	shadow.texture = _shadow_tex
	shadow.position = Vector2(0, 12)
	shadow.modulate = Color(0, 0, 0, 0.35)
	if a.is_boss:
		shadow.scale = Vector2(1.45, 1.45)
	s.add_child(shadow)
	return s


func _draw() -> void:
	if state == null:
		return
	var board := Rect2(GameConfig.BOARD_X, GameConfig.BOARD_Y, GameConfig.BOARD_W, GameConfig.BOARD_H)
	draw_rect(board, theme_bg.darkened(0.45))

	for y in GameConfig.GRID_H:
		for x in GameConfig.GRID_W:
			var c := Vector2i(x, y)
			if not state.is_explored(c):
				continue
			var r := GameConfig.cell_rect(c)
			var wall := state.is_wall(c)
			if has_sheet:
				var tint := tile_tint
				if wall:
					tint = Color(tile_tint.r * 1.45, tile_tint.g * 1.4, tile_tint.b * 1.3, 1.0)
				else:
					tint = Color(tile_tint.r * 1.72, tile_tint.g * 1.66, tile_tint.b * 1.6, 1.0)
				draw_texture_rect_region(sheet, r, WALL_REGION if wall else FLOOR_REGION, tint)
			else:
				draw_rect(r, theme_wall if wall else theme_floor)
			if wall:
				_draw_wall_shading(r)
			if not state.is_visible(c):
				draw_rect(r, GameConfig.COL_MEMORY)

	# 网格线：只画在已探索区域，避免未探索区出现"棋盘格"
	var gc := Color(1, 1, 1, 0.045)
	for y in GameConfig.GRID_H:
		for x in GameConfig.GRID_W:
			var cc := Vector2i(x, y)
			if not state.is_explored(cc):
				continue
			var rr := GameConfig.cell_rect(cc)
			draw_line(rr.position, rr.position + Vector2(rr.size.x, 0), gc, 1.0)
			draw_line(rr.position, rr.position + Vector2(0, rr.size.y), gc, 1.0)

	_draw_props()
	_draw_border(board)


func _draw_wall_shading(r: Rect2) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.10))
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 2)), Color(1, 1, 1, 0.035))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 7), Vector2(r.size.x, 7)), Color(0, 0, 0, 0.26))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(0, 0, 0, 0.34))


func _draw_props() -> void:
	for c in state.props.keys():
		if not state.is_explored(c):
			continue
		var r := GameConfig.cell_rect(c)
		var kind := String(state.props[c])
		if kind == "stairs":
			var base := r.position + Vector2(4, 4)
			for i in 4:
				var col := Color("#2b2f3a").lerp(Color("#e8d9a0"), float(i) / 3.0)
				draw_rect(Rect2(base + Vector2(0, i * 6), Vector2(24, 6)), col)
				draw_rect(Rect2(base + Vector2(0, i * 6), Vector2(24, 1)), Color(1, 1, 1, 0.22))
			draw_rect(Rect2(r.position, r.size), Color(1, 0.94, 0.6, 0.10))
		elif kind == "shop":
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(28, 28)), Color("#3a2f18"))
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(28, 28)), Color("#c9a227"), false, 2.0)
			draw_string(Art.font, r.position + Vector2(6, 24), "商", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f0d97a"))


func _draw_border(board: Rect2) -> void:
	draw_rect(board, Color("#4a4f5c"), false, 2.0)
	draw_rect(board.grow(2), Color(0, 0, 0, 0.5), false, 2.0)
