class_name Actor
extends RefCounted

var def_id := ""
var display_name := "?"
var pos := Vector2i.ZERO

var hp := 1
var max_hp := 1
var mp := 0
var max_mp := 0
var atk := 1
var defense := 0

var level := 1
var xp := 0            # 玩家当前经验
var xp_value := 0      # 怪物被击杀时给出的经验
var gold_value := 0

var traits: Array = []
var aggro := false
var is_player := false
var is_boss := false
var sprite := ""
var color := "#888888"
var status: Dictionary = {}   # {"poison": 剩余回合, "stealth": 1}
var dead := false
var flash := 0.0
var bob_seed := 0.0
var stunned := 0


func has_trait(t: String) -> bool:
	return traits.has(t) or (t == "aggro" and aggro)


func hp_ratio() -> float:
	return clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)


func is_alive() -> bool:
	return not dead and hp > 0
