extends Control

const Combatant = preload("res://battle/combatant.gd")

const VARIANCE := 0.15

const OVERWORLD_SCENE := "res://main/world.tscn"

# Base stats + sprite per overworld enemy type. Unknown types fall back to thug.
const BASE_STATS := {
	"thug": {
		"cname": "Thug", "max_hp": 12, "attack": 6, "defense": 1, "agility": 5,
		"texture": preload("res://assets/enemy_thug.png"),
	},
	"drone": {
		"cname": "Drone", "max_hp": 10, "attack": 5, "defense": 3, "agility": 7,
		"texture": preload("res://assets/enemy_drone.png"),
	},
}

# How long the result line stays up before we drop back to the map.
const EXIT_DELAY := 1.2

# When true, damage has no random variance — repeatable math for the tests.
var deterministic: bool = false

var player
var enemies: Array = []

var _order: Array = []
var _turn_index := 0
var _acting_enemy = null
var _fled := false

@onready var _player_hp: Label = $PlayerBox/HP
@onready var _enemy_boxes: Array = [$EnemyRow/Enemy0, $EnemyRow/Enemy1]
@onready var _log: Label = $Log
@onready var _menu: VBoxContainer = $Menu
@onready var _target_menu: VBoxContainer = $TargetMenu
@onready var _enemy_timer: Timer = $EnemyTimer


func _ready() -> void:
	player = _new_player()
	enemies = [
		Combatant.new("Thug", 12, 6, 1, 5),
		Combatant.new("Drone", 10, 5, 3, 7),
	]

	$Menu/Attack.pressed.connect(_on_attack_pressed)
	$Menu/Defend.pressed.connect(_on_defend_pressed)
	$Menu/Flee.pressed.connect(_on_flee_pressed)
	_enemy_timer.timeout.connect(_on_enemy_timer_timeout)

	# Fought from the overworld: the mob you touched is the mob you fight. Run
	# standalone (no autoload, no pending encounter) and you get the default pair.
	var gm = get_node_or_null("/root/Game")
	if gm != null and gm.pending_enemy_type != "":
		setup_from_type(gm.pending_enemy_type)

	_refresh()
	_start_round()


# Rebuilds the roster as the player plus exactly one enemy of `enemy_type`.
func setup_from_type(enemy_type: String) -> void:
	var base: Dictionary = BASE_STATS.get(enemy_type, BASE_STATS["thug"])
	player = _new_player()
	enemies = [Combatant.new(
		base["cname"],
		_roll(base["max_hp"]),
		_roll(base["attack"]),
		_roll(base["defense"]),
		_roll(base["agility"]),
	)]

	_enemy_boxes[0].get_node("Sprite").texture = base["texture"]
	_say("A %s blocks your path!" % base["cname"].to_lower())
	_refresh()


func _new_player():
	return Combatant.new("You", 30, 10, 2, 8)


# A stat rolled ±VARIANCE off its base, or the base itself when deterministic.
func _roll(base: int) -> int:
	if deterministic:
		return base
	return max(1, roundi(base * randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)))


# --- battle logic (the acceptance test's contract) ---

# Living combatants, fastest first.
func turn_order() -> Array:
	var living := []
	if player.is_alive():
		living.append(player)
	for e in enemies:
		if e.is_alive():
			living.append(e)
	living.sort_custom(func(a, b): return a.agility > b.agility)
	return living


# Applies damage to `target` and returns the amount dealt.
func do_attack(attacker, target) -> int:
	var dmg: int = max(1, attacker.attack - target.defense)
	if target.defending:
		dmg = max(1, dmg / 2)
	if not deterministic:
		var spread: float = dmg * VARIANCE
		dmg = max(1, roundi(dmg + randf_range(-spread, spread)))
	target.hp = max(0, target.hp - dmg)
	return dmg


func is_over() -> bool:
	if not player.is_alive():
		return true
	for e in enemies:
		if e.is_alive():
			return false
	return true


func winner() -> String:
	if not is_over():
		return ""
	if player.is_alive():
		return "player"
	return "enemies"


# --- turn loop ---

func _start_round() -> void:
	_order = turn_order()
	_turn_index = 0
	_next_turn()


func _next_turn() -> void:
	if is_over() or _fled:
		_end_battle()
		return
	# Skip anyone who died earlier in the round.
	while _turn_index < _order.size() and not _order[_turn_index].is_alive():
		_turn_index += 1
	if _turn_index >= _order.size():
		_start_round()
		return

	var actor = _order[_turn_index]
	# A Defend lasts until the defender's next turn comes round.
	actor.defending = false
	if actor == player:
		_show_menu()
	else:
		_hide_menus()
		_acting_enemy = actor
		_enemy_timer.start()


func _advance() -> void:
	_turn_index += 1
	_refresh()
	_next_turn()


func _on_enemy_timer_timeout() -> void:
	var dmg := do_attack(_acting_enemy, player)
	_say("%s hits you for %d." % [_acting_enemy.cname, dmg])
	_acting_enemy = null
	_advance()


func _end_battle() -> void:
	_hide_menus()
	_refresh()
	if _fled:
		_say("You fled the fight.")
	elif winner() == "player":
		_say("Victory! All enemies are down.")
	else:
		_say("You are down. Defeat...")
	_return_to_overworld()


func _return_to_overworld() -> void:
	# Fleeing is its own result: you didn't win, so the enemy is still out there.
	Game.end_battle("fled" if _fled else winner())
	await get_tree().create_timer(EXIT_DELAY).timeout
	get_tree().change_scene_to_file(OVERWORLD_SCENE)


# --- player actions ---

func _on_attack_pressed() -> void:
	_menu.hide()
	for child in _target_menu.get_children():
		child.queue_free()
	for e in enemies:
		if not e.is_alive():
			continue
		var button := Button.new()
		button.text = "%s (%d HP)" % [e.cname, e.hp]
		button.pressed.connect(_on_target_pressed.bind(e))
		_target_menu.add_child(button)
	_target_menu.show()


func _on_target_pressed(target) -> void:
	_hide_menus()
	var dmg := do_attack(player, target)
	var suffix := " It goes down!" if not target.is_alive() else ""
	_say("You hit %s for %d.%s" % [target.cname, dmg, suffix])
	_advance()


func _on_defend_pressed() -> void:
	_hide_menus()
	player.defending = true
	_say("You brace for impact.")
	_advance()


func _on_flee_pressed() -> void:
	_fled = true
	_end_battle()


# --- ui ---

func _show_menu() -> void:
	_target_menu.hide()
	_menu.show()


func _hide_menus() -> void:
	_menu.hide()
	_target_menu.hide()


func _say(text: String) -> void:
	_log.text = text


func _refresh() -> void:
	_player_hp.text = "You  %d/%d" % [player.hp, player.max_hp]
	for i in _enemy_boxes.size():
		var box: Control = _enemy_boxes[i]
		box.visible = i < enemies.size()
		if not box.visible:
			continue
		var e = enemies[i]
		box.get_node("HP").text = "%s  %d/%d" % [e.cname, e.hp, e.max_hp]
		box.modulate.a = 1.0 if e.is_alive() else 0.3
