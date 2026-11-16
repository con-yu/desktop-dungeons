extends Node2D

## 主控：界面状态机 + 输入 + 与 DungeonState 的胶水。

const DEBUG_FIXED_SEED := false

@onready var view: DungeonView = $DungeonView
@onready var hud: Hud = $Hud

var state: DungeonState
var screen := "title"
var pending_level := 0
var _move_cd := 0.0
var _shop_return := "play"


func _ready() -> void:
	GameConfig.setup_input()
	hud.level_chosen.connect(_on_level_chosen)
	hud.class_chosen.connect(_on_class_chosen)
	hud.item_clicked.connect(_on_item_clicked)
	hud.skill_clicked.connect(_on_skill)
	hud.shop_buy.connect(_on_shop_buy)
	hud.shop_close.connect(_on_shop_close)
	hud.next_level.connect(_on_next_level)
	hud.retry_level.connect(_on_retry)
	hud.to_title.connect(_goto_title)
	view.visible = false
	_goto_title()
	_handle_debug_args()


## 开发用：--autoplay 直接进入第一关，--shot 截图后退出（用于自动化验证画面）。
func _handle_debug_args() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if not args.has("--autoplay"):
		return
	var lvl := 0
	for a in args:
		if a.begins_with("--level="):
			lvl = int(a.substr(8))
	var cls := "fighter"
	for a in args:
		if a.begins_with("--class="):
			cls = a.substr(8)
	await get_tree().process_frame
	_start_level(lvl, cls)
	if args.has("--shot"):
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://shot.png")
		img.save_png(path)
		print("截图已保存: ", path)
		get_tree().quit()


func _goto_title() -> void:
	screen = "title"
	state = null
	view.visible = false
	hud.state = null
	hud.screen = "title"
	hud.queue_redraw()
	Sfx.play_music("title", -18.0)


func _on_level_chosen(index: int) -> void:
	pending_level = index
	hud.screen = "class"
	hud.stats = {"level_index": index}
	hud.queue_redraw()
	Sfx.play("click")


func _on_class_chosen(class_id: String) -> void:
	Sfx.play("click")
	_start_level(pending_level, class_id)


func _start_level(index: int, class_id: String) -> void:
	state = DungeonState.new()
	var seed_value := 4000 + index * 7919 if DEBUG_FIXED_SEED else 0
	state.new_run(index, class_id, seed_value)
	screen = "play"
	view.visible = true
	view.setup(state)
	hud.state = state
	hud.screen = "play"
	hud.stats = {"level_index": index, "kills": 0}
	hud.queue_redraw()
	Sfx.play_music("dungeon", -18.0)


func _on_retry() -> void:
	if state != null:
		_start_level(state.level_index, state.class_id)


func _on_next_level() -> void:
	var next := state.level_index + 1
	if next < DB.levels.size():
		pending_level = next
		hud.screen = "class"
		hud.stats = {"level_index": next}
		hud.queue_redraw()
		view.visible = false
		screen = "class"
	else:
		_goto_title()


func _on_skill() -> void:
	if screen != "play" or state == null:
		return
	_perform("skill")


func _on_item_clicked(item_id: String) -> void:
	if screen == "shop":
		return
	if screen != "play" or state == null:
		return
	if state.use_item(item_id):
		_after_action()


func _on_shop_buy(index: int) -> void:
	if state == null:
		return
	if state.buy(index):
		hud.queue_redraw()


func _on_shop_close() -> void:
	screen = "play"
	hud.screen = "play"
	hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if screen != "play":
			hud.queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var key := hud.hit_test(mb.position)
			if key != "":
				hud.trigger(key)
				get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed:
			return
		if k.echo:
			return
		_handle_key(k)


func _handle_key(k: InputEventKey) -> void:
	match screen:
		"play":
			if k.is_action("move_up"):
				_perform("move", Vector2i(0, -1))
			elif k.is_action("move_down"):
				_perform("move", Vector2i(0, 1))
			elif k.is_action("move_left"):
				_perform("move", Vector2i(-1, 0))
			elif k.is_action("move_right"):
				_perform("move", Vector2i(1, 0))
			elif k.is_action("wait"):
				_perform("wait")
			elif k.is_action("skill"):
				_perform("skill")
			elif k.is_action("use_potion"):
				_use_first_potion()
			elif k.is_action("restart"):
				_on_retry()
			elif k.is_action("cancel"):
				_goto_title()
		"shop":
			if k.keycode == KEY_1:
				_on_shop_buy(0)
			elif k.keycode == KEY_2:
				_on_shop_buy(1)
			elif k.keycode == KEY_3:
				_on_shop_buy(2)
			elif k.is_action("cancel"):
				_on_shop_close()
		"win":
			if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
				_on_next_level()
			elif k.is_action("cancel"):
				_goto_title()
		"lose":
			if k.is_action("restart") or k.keycode == KEY_ENTER:
				_on_retry()
			elif k.is_action("cancel"):
				_goto_title()
		"class":
			if k.is_action("cancel"):
				_goto_title()
		"title":
			pass


func _use_first_potion() -> void:
	if state == null:
		return
	for iid in state.items.keys():
		var d := DB.item_def(iid)
		if String(d.get("type", "")) == "potion":
			_on_item_clicked(String(iid))
			return
	# 没有药水则用掉第一个可用道具
	for iid in state.items.keys():
		_on_item_clicked(String(iid))
		return


func _perform(kind: String, dir := Vector2i.ZERO) -> void:
	if state == null or screen != "play":
		return
	if not state.player_action(kind, dir):
		view.refresh()
		return
	_after_action()


func _after_action() -> void:
	view.refresh()
	hud.queue_redraw()

	if state.player_dead:
		screen = "lose"
		hud.screen = "lose"
		hud.queue_redraw()
		Sfx.stop_music()
		return

	if state.victory:
		hud.stats["kills"] = state.kills
		hud.screen = "win"
		screen = "win"
		DB.mark_cleared(state.level_index)
		hud.queue_redraw()
		return

	# 踩到商店格
	if state.props.get(state.player.pos, "") == "shop":
		screen = "shop"
		hud.screen = "shop"
		hud.queue_redraw()
		Sfx.play("shop")


func _process(delta: float) -> void:
	if state != null:
		state.tick_fx(delta)
		for m in state.monsters:
			if m.flash > 0.0:
				m.flash = maxf(0.0, m.flash - delta)
		state.player.bob_seed += delta
	if _move_cd > 0.0:
		_move_cd -= delta
