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

# The player's three battle skills. Each is limited a different way: energy,
# cooldown, or both.
const SKILL_DEFS := [
	{"id": "power_strike", "sname": "Power Strike", "kind": "damage", "cost": 3, "cooldown": 0, "power": 8},
	{"id": "heal", "sname": "Heal", "kind": "heal", "cost": 5, "cooldown": 2, "power": 12},
	{"id": "guard_up", "sname": "Guard Up", "kind": "buff", "cost": 0, "cooldown": 3, "power": 4},
]

const _SKILL_BUTTONS := {
	"power_strike": "PowerStrike",
	"heal": "Heal",
	"guard_up": "GuardUp",
}

# When true, damage has no random variance — repeatable math for the tests.
var deterministic: bool = false

var player
var enemies: Array = []

var player_max_energy: int = 10
var player_energy: int = 10

var _order: Array = []
var _turn_index := 0
var _acting_enemy = null
var _fled := false
# skill id -> turns left before it can be used again.
var _skill_cooldowns: Dictionary = {}
# Which skill the open target menu is picking a target for ("" = plain Attack).
var _pending_skill := ""

@onready var _player_hp: Label = $PlayerBox/HP
@onready var _player_energy_label: Label = $PlayerBox/Energy
@onready var _enemy_boxes: Array = [$EnemyRow/Enemy0, $EnemyRow/Enemy1]
@onready var _log: Label = $Log
@onready var _menu: VBoxContainer = $Menu
@onready var _target_menu: VBoxContainer = $TargetMenu
@onready var _enemy_timer: Timer = $EnemyTimer
@onready var _banner: Label = $Banner
@onready var _loot: Label = $Loot
@onready var _game_over: Control = $GameOver


func _ready() -> void:
	player = _new_player()
	enemies = [
		Combatant.new("Thug", 12, 6, 1, 5),
		Combatant.new("Drone", 10, 5, 3, 7),
	]
	_reset_skills()

	$Menu/Attack.pressed.connect(_on_attack_pressed)
	$Menu/PowerStrike.pressed.connect(_on_skill_pressed.bind("power_strike"))
	$Menu/Heal.pressed.connect(_on_skill_pressed.bind("heal"))
	$Menu/GuardUp.pressed.connect(_on_skill_pressed.bind("guard_up"))
	$Menu/Defend.pressed.connect(_on_defend_pressed)
	$Menu/Flee.pressed.connect(_on_flee_pressed)
	$GameOver/Restart.pressed.connect(_on_restart_pressed)
	_enemy_timer.timeout.connect(_on_enemy_timer_timeout)

	# Fought from the overworld: the mob you touched is the mob you fight. Run
	# standalone (no autoload, no pending encounter) and you get the default pair.
	var gm = get_node_or_null("/root/Game")
	if gm != null:
		if gm.pending_enemy_type != "":
			setup_from_type(gm.pending_enemy_type)
		# You walk in as hurt as you walked out of the last fight.
		apply_player_stats(
			gm.player_hp, gm.player_max_hp,
			gm.player_attack, gm.player_defense, gm.player_agility,
		)

	_refresh()
	_start_round()


# Rebuilds the roster as the player plus exactly one enemy of `enemy_type`.
func setup_from_type(enemy_type: String) -> void:
	var base: Dictionary = BASE_STATS.get(enemy_type, BASE_STATS["thug"])
	player = _new_player()
	_reset_skills()
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


# Seeds the player combatant from carried-over state instead of a fresh 30/30.
func apply_player_stats(hp: int, max_hp: int, atk: int, dfn: int, agi: int) -> void:
	player = Combatant.new("You", max_hp, atk, dfn, agi)
	player.hp = clampi(hp, 0, max_hp)
	_refresh()


func player_current_hp() -> int:
	return player.hp


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


# --- skills (the acceptance test's contract) ---

# Full energy, every skill off cooldown.
func _reset_skills() -> void:
	player_energy = player_max_energy
	_skill_cooldowns.clear()
	for s in SKILL_DEFS:
		_skill_cooldowns[s["id"]] = 0


func available_skills() -> Array:
	var out := []
	for s in SKILL_DEFS:
		out.append({
			"id": s["id"],
			"sname": s["sname"],
			"cost": s["cost"],
			"cooldown": s["cooldown"],
			"current_cooldown": _skill_cooldowns.get(s["id"], 0),
		})
	return out


func can_use_skill(skill_id: String) -> bool:
	var s := _skill_def(skill_id)
	if s.is_empty():
		return false
	return player_energy >= int(s["cost"]) and int(_skill_cooldowns.get(skill_id, 0)) == 0


# Spends the skill and applies its effect. A no-op returning {"ok": false} if the
# skill is out of energy or still cooling down.
func use_skill(skill_id: String, target) -> Dictionary:
	if not can_use_skill(skill_id):
		return {"ok": false}
	var s := _skill_def(skill_id)
	player_energy -= int(s["cost"])
	_skill_cooldowns[skill_id] = int(s["cooldown"])

	var result := {"ok": true}
	match s["kind"]:
		"damage":
			var dmg: int = max(1, (player.attack + int(s["power"])) - target.defense)
			if not deterministic:
				var spread: float = dmg * VARIANCE
				dmg = max(1, roundi(dmg + randf_range(-spread, spread)))
			target.hp = max(0, target.hp - dmg)
			result["damage"] = dmg
		"heal":
			var before: int = target.hp
			target.hp = min(target.max_hp, target.hp + int(s["power"]))
			result["heal"] = target.hp - before
		"buff":
			target.defense += int(s["power"])
			result["buff"] = int(s["power"])
	_refresh()
	return result


# Every skill cools down by one turn. Called at the top of each player turn.
func tick_skill_cooldowns() -> void:
	for id in _skill_cooldowns:
		_skill_cooldowns[id] = max(0, int(_skill_cooldowns[id]) - 1)


func _skill_def(skill_id: String) -> Dictionary:
	for s in SKILL_DEFS:
		if s["id"] == skill_id:
			return s
	return {}


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
		tick_skill_cooldowns()
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

	# The HP you walk away with is the HP you bring to the next fight.
	var gm = get_node_or_null("/root/Game")
	if gm != null:
		gm.set_player_hp(player_current_hp())
		if gm.is_game_over():
			_say("You are down. Defeat...")
			_game_over.show()
			return

	# Fleeing is its own result: you didn't win, so the enemy is still out there.
	# Settling it here (not on the way out) means the win's loot is already banked
	# by the time we put the summary on screen.
	Game.end_battle("fled" if _fled else winner())

	if _fled:
		_say("You fled the fight.")
	elif winner() == "player":
		_say("Victory! All enemies are down.")
		_banner.show()
		_loot.text = _loot_summary(Game.last_loot)
		_loot.show()
	else:
		_say("You are down. Defeat...")
	_return_to_overworld()


# "+8 scrap, found bandage" — the item half only when something dropped.
func _loot_summary(loot: Dictionary) -> String:
	var text: String = "+%d scrap" % int(loot.get("scrap", 0))
	var item: String = loot.get("item", "")
	if item != "":
		text += ", found %s" % item.replace("_", " ")
	return text


func _on_restart_pressed() -> void:
	Game.reset_player()
	get_tree().change_scene_to_file(OVERWORLD_SCENE)


func _return_to_overworld() -> void:
	await get_tree().create_timer(EXIT_DELAY).timeout
	get_tree().change_scene_to_file(OVERWORLD_SCENE)


# --- player actions ---

func _on_attack_pressed() -> void:
	_pending_skill = ""
	_show_targets()


# Self-targeted skills fire straight away; a damage skill picks its target first.
func _on_skill_pressed(skill_id: String) -> void:
	if not can_use_skill(skill_id):
		return
	var s := _skill_def(skill_id)
	if s["kind"] == "damage":
		_pending_skill = skill_id
		_show_targets()
		return
	_hide_menus()
	var r := use_skill(skill_id, player)
	if r.has("heal"):
		_say("You patch yourself up for %d." % r["heal"])
	else:
		_say("Your guard tightens. +%d defense." % r["buff"])
	_advance()


func _show_targets() -> void:
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
	var dmg := 0
	if _pending_skill == "":
		dmg = do_attack(player, target)
	else:
		dmg = int(use_skill(_pending_skill, target).get("damage", 0))
		_pending_skill = ""
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


# Each skill button reads out its cost, and its remaining cooldown when it has one.
func _refresh_skill_buttons() -> void:
	for s in available_skills():
		var button: Button = _menu.get_node(_SKILL_BUTTONS[s["id"]])
		var label: String = "%s (%dE)" % [s["sname"], s["cost"]]
		if s["current_cooldown"] > 0:
			label += " CD %d" % s["current_cooldown"]
		button.text = label
		button.disabled = not can_use_skill(s["id"])


func _refresh() -> void:
	_player_hp.text = "You  %d/%d" % [player.hp, player.max_hp]
	_player_energy_label.text = "Energy  %d/%d" % [player_energy, player_max_energy]
	_refresh_skill_buttons()
	for i in _enemy_boxes.size():
		var box: Control = _enemy_boxes[i]
		box.visible = i < enemies.size()
		if not box.visible:
			continue
		var e = enemies[i]
		box.get_node("HP").text = "%s  %d/%d" % [e.cname, e.hp, e.max_hp]
		box.modulate.a = 1.0 if e.is_alive() else 0.3
