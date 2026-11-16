class_name OverlayView
extends Node2D

## 动态层：血条、格子高亮、伤害飘字（每帧重绘，绘制量很小）。

var state: DungeonState
var view: DungeonView


func _draw() -> void:
	if state == null:
		return
	_draw_highlights()
	_draw_health_bars()
	_draw_fx()


func _draw_highlights() -> void:
	var p := state.player
	if p == null:
		return
	var r := GameConfig.cell_rect(p.pos)
	draw_rect(r, Color(1.0, 0.92, 0.5, 0.10))
	draw_rect(r, Color(1.0, 0.92, 0.5, 0.42), false, 1.0)
	if p.status.get("stealth", 0) > 0:
		draw_rect(r.grow(-3), Color(0.42, 0.75, 0.95, 0.45), false, 2.0)

	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var m := state.monster_at(p.pos + d)
		if m != null:
			var mr := GameConfig.cell_rect(m.pos)
			if m.is_boss:
				draw_rect(mr, Color(1.0, 0.55, 0.25, 0.55), false, 2.0)
			else:
				draw_rect(mr, Color(0.85, 0.35, 0.3, 0.35), false, 1.0)

	if state.boss != null and state.boss.is_alive() and state.is_explored(state.boss.pos):
		var br := GameConfig.cell_rect(state.boss.pos)
		draw_rect(br.grow(1), Color(1.0, 0.8, 0.3, 0.28 + sin(Time.get_ticks_msec() * 0.004) * 0.12), false, 2.0)


func _draw_health_bars() -> void:
	for m in state.monsters:
		if not m.is_alive() or not state.is_explored(m.pos):
			continue
		if m.hp >= m.max_hp and not m.is_boss:
			continue
		var r := GameConfig.cell_rect(m.pos)
		var w: float = 22.0 if not m.is_boss else 26.0
		var pos := Vector2(r.position.x + (GameConfig.TILE - w) * 0.5, r.position.y - 4)
		var bg := Rect2(pos, Vector2(w, 3))
		draw_rect(bg, Color(0, 0, 0, 0.65))
		draw_rect(Rect2(pos, Vector2(w * m.hp_ratio(), 3)), Color("#d2484c") if not m.is_boss else Color("#e0762c"))
		if m.has_trait("poison"):
			draw_rect(Rect2(pos + Vector2(w + 2, 0), Vector2(2, 3)), Color("#7bc47f"))
		if m.has_trait("undead"):
			draw_rect(Rect2(pos - Vector2(4, 0), Vector2(2, 3)), Color("#9fb6c9"))


func _draw_fx() -> void:
	for f in state.fx_list:
		var t: float = f.get("t", 0.0)
		var pos := GameConfig.cell_center(f.pos)
		var y := pos.y - 10 - t * 20.0
		var col: Color = f.color
		col.a = clampf(1.0 - t * 1.15, 0.0, 1.0)
		var txt := String(f.text)
		var size := 13
		var w := Art.font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(Art.font, Vector2(pos.x - w * 0.5 + 1, y + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.8))
		draw_string(Art.font, Vector2(pos.x - w * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
