extends RefCounted

var cname: String
var hp: int
var max_hp: int
var attack: int
var defense: int
var agility: int
var defending: bool = false


func _init(p_name: String, p_max_hp: int, p_attack: int, p_defense: int, p_agility: int) -> void:
	cname = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	attack = p_attack
	defense = p_defense
	agility = p_agility


func is_alive() -> bool:
	return hp > 0
