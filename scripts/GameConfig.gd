class_name GameConfig
extends RefCounted

## 全局常量：32px 网格、1280x720 画布，像素 1:1 不缩放。

const TILE := 32
const GRID_W := 26
const GRID_H := 16

const BOARD_X := 44
const BOARD_Y := 92
const BOARD_W := GRID_W * TILE
const BOARD_H := GRID_H * TILE

const PANEL_X := 892
const PANEL_Y := 92
const PANEL_W := 344
const PANEL_H := 512

const LOG_Y := 612

# 配色（未拿到 AI 素材时的兜底层，同时也是 UI 基调）
const COL_BG := Color("#0a0b0f")
const COL_FLOOR := Color("#2b2f3a")
const COL_FLOOR_ALT := Color("#242833")
const COL_WALL := Color("#4a4136")
const COL_WALL_TOP := Color("#5d5346")
const COL_FOG := Color("#05060a")
const COL_MEMORY := Color(0.02, 0.02, 0.05, 0.62)
const COL_GRID := Color(1, 1, 1, 0.045)
const COL_TEXT := Color("#d8d4c6")
const COL_DIM := Color("#8b8778")
const COL_HP := Color("#c4454a")
const COL_MP := Color("#4a7bc4")
const COL_XP := Color("#c9a227")
const COL_GOLD := Color("#d4af37")
const COL_PANEL_BG := Color("#161a22")
const COL_PANEL_EDGE := Color("#3b4250")
const COL_HILITE := Color(1.0, 0.92, 0.55, 0.35)

# 探索回血：踏入一个未探索格获得
const EXPLORE_HP := 2
const EXPLORE_MP := 1
const EXPLORE_CLAIRVOYANCE := 1  # 揭示半径（1 => 3x3）

const LEVEL_XP := [8, 14, 22, 32, 45, 60, 80, 105, 135, 170, 210, 255, 305, 360]

const DIRS := {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}

static func xp_needed(level: int) -> int:
	if level - 1 < LEVEL_XP.size():
		return int(LEVEL_XP[level - 1])
	return int(LEVEL_XP[LEVEL_XP.size() - 1]) + (level - LEVEL_XP.size()) * 60


static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(BOARD_X + c.x * TILE, BOARD_Y + c.y * TILE, TILE, TILE)


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(BOARD_X + c.x * TILE + TILE * 0.5, BOARD_Y + c.y * TILE + TILE * 0.5)


static func setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"wait": [KEY_SPACE, KEY_PERIOD],
		"skill": [KEY_Q, KEY_1],
		"use_potion": [KEY_E, KEY_2],
		"restart": [KEY_R],
		"cancel": [KEY_ESCAPE],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
