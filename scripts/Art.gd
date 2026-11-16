extends Node

## 素材与字体的统一入口（autoload: Art）

const CHARS := "res://assets/chars/"
const MONSTERS := "res://assets/monsters/"
const ITEMS := "res://assets/items/"
const UI := "res://assets/ui/"

var _tex_cache: Dictionary = {}
var _ph_cache: Dictionary = {}
var _shadow: Texture2D
var font: Font
var font_bold: Font


func _ready() -> void:
	_setup_fonts()


func _setup_fonts() -> void:
	# 优先用随包的中文子集字体（体积小、Web 也能用），缺失时回退系统字体
	var path := "res://assets/fonts/ui_zh.ttf"
	if ResourceLoader.exists(path):
		font = load(path)
		var bp := "res://assets/fonts/ui_zh_bold.ttf"
		font_bold = load(bp) if ResourceLoader.exists(bp) else font
		return
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC",
		"Noto Sans CJK SC", "Source Han Sans SC",
		"Microsoft YaHei", "sans-serif",
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font = f
	font_bold = f


func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[path] = t
	return t


func char_tex(class_id: String, dir: String = "south") -> Texture2D:
	var t := tex(CHARS + "%s_%s.png" % [class_id, dir])
	if t == null:
		t = tex(CHARS + "%s_south.png" % class_id)
	return t


func monster_tex(sprite: String) -> Texture2D:
	return tex(MONSTERS + sprite + ".png")


func item_tex(sprite: String) -> Texture2D:
	return tex(ITEMS + sprite + ".png")


func ui_tex(name: String) -> Texture2D:
	return tex(UI + name + ".png")


## 实体脚下的椭圆阴影。
func shadow_tex() -> Texture2D:
	if _shadow != null:
		return _shadow
	var w := 22
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := (x - (w - 1) * 0.5) / ((w - 1) * 0.5)
			var dy := (y - (h - 1) * 0.5) / ((h - 1) * 0.5)
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.5 * (1.0 - d * 0.55)))
	_shadow = ImageTexture.create_from_image(img)
	return _shadow


## 缺素材时的占位：纯色块 + 描边 + 首字。
func placeholder(color: Color, label := "") -> Texture2D:
	var key := color.to_html() + label
	if _ph_cache.has(key):
		return _ph_cache[key]
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inner := Rect2i(6, 6, 20, 20)
	for y in size:
		for x in size:
			var p := Vector2i(x, y)
			if inner.has_point(p):
				if x == inner.position.x or y == inner.position.y or x == inner.position.x + inner.size.x - 1 or y == inner.position.y + inner.size.y - 1:
					img.set_pixel(x, y, color.darkened(0.55))
				else:
					img.set_pixel(x, y, color)
	var t := ImageTexture.create_from_image(img)
	_ph_cache[key] = t
	return t
