extends Node

# Cross-scene state for the overworld <-> battle handoff. Autoloaded as `Game`.

var overworld_return_pos: Vector2i = Vector2i.ZERO
var pending_enemy_id: int = -1
var pending_enemy_type: String = ""
var last_result: String = ""
var respawn_delay: float = 8.0

# The player's stats survive between fights: damage taken sticks until Restart.
var player_max_hp: int = 30
var player_hp: int = 30
var player_attack: int = 10
var player_defense: int = 2
var player_agility: int = 8

var player_level: int = 1
var player_xp: int = 0

var scrap: int = 0
# item_id -> quantity.
var inventory: Dictionary = {}
# What the last won fight dropped, for the battle screen's loot summary.
var last_loot: Dictionary = {}

# What each enemy type drops. Rolls below `chance` land the item.
const LOOT_TABLES := {
	"thug": {
		"scrap_min": 5, "scrap_max": 15,
		"common": {"id": "bandage", "chance": 0.40},
		"rare": {"id": "stimpack", "chance": 0.05},
	},
	"drone": {
		"scrap_min": 8, "scrap_max": 20,
		"common": {"id": "scrap_metal", "chance": 0.40},
		"rare": {"id": "power_cell", "chance": 0.08},
	},
}

# enemy_id -> seconds left until it respawns.
var _defeated: Dictionary = {}


func set_player_hp(hp: int) -> void:
	player_hp = clampi(hp, 0, player_max_hp)


func is_game_over() -> bool:
	return player_hp <= 0


func reset_player() -> void:
	player_max_hp = 30
	player_hp = player_max_hp
	player_attack = 10
	player_defense = 2
	player_agility = 8
	player_level = 1
	player_xp = 0
	scrap = 0
	inventory = {}
	last_loot = {}


# XP needed to go from `level` to `level + 1`.
func xp_for_level(level: int) -> int:
	return int(round(50.0 * pow(level, 1.5) + 25.0 * level))


func xp_reward(enemy_type: String) -> int:
	match enemy_type:
		"thug":
			return 30
		"drone":
			return 40
		_:
			return 0


# Banks XP, spending it on as many levels as it covers. Returns levels gained.
func gain_xp(amount: int) -> int:
	player_xp += amount
	var gained := 0
	while player_xp >= xp_for_level(player_level):
		player_xp -= xp_for_level(player_level)
		_level_up()
		gained += 1
	return gained


func _level_up() -> void:
	player_level += 1
	player_max_hp += 5
	player_attack += 2
	player_defense += 1
	player_agility += 1
	player_hp = player_max_hp


# --- loot ---

func add_scrap(n: int) -> void:
	scrap += n


func add_item(item_id: String, qty: int = 1) -> void:
	inventory[item_id] = item_count(item_id) + qty


func item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


# An unknown enemy type drops nothing.
func loot_table(enemy_type: String) -> Dictionary:
	return LOOT_TABLES.get(enemy_type, {})


# Pure: the same two rolls always give the same drop. `roll_loot` supplies the RNG.
func resolve_loot(enemy_type: String, scrap_roll: float, item_roll: float) -> Dictionary:
	var table := loot_table(enemy_type)
	if table.is_empty():
		return {"scrap": 0, "item": ""}

	var scrap_min: int = table["scrap_min"]
	var scrap_max: int = table["scrap_max"]
	var dropped: int = scrap_min + int(round((scrap_max - scrap_min) * scrap_roll))

	var rare: Dictionary = table["rare"]
	var common: Dictionary = table["common"]
	var item := ""
	if item_roll < float(rare["chance"]):
		item = rare["id"]
	elif item_roll < float(rare["chance"]) + float(common["chance"]):
		item = common["id"]

	return {"scrap": dropped, "item": item}


func roll_loot(enemy_type: String) -> Dictionary:
	return resolve_loot(enemy_type, randf(), randf())


func award_loot(enemy_type: String) -> Dictionary:
	var loot := roll_loot(enemy_type)
	add_scrap(loot["scrap"])
	if loot["item"] != "":
		add_item(loot["item"])
	return loot


# Records the enemy that triggered the fight and where to put the player back.
func begin_battle(enemy_id: int, return_pos: Vector2i, enemy_type: String = "") -> void:
	pending_enemy_id = enemy_id
	pending_enemy_type = enemy_type
	overworld_return_pos = return_pos
	last_result = ""


# Only a "player" result beats the enemy; fleeing or losing leaves it standing.
func end_battle(result: String) -> void:
	last_result = result
	if result == "player" and pending_enemy_id != -1:
		_defeated[pending_enemy_id] = respawn_delay
		gain_xp(xp_reward(pending_enemy_type))
		last_loot = award_loot(pending_enemy_type)


func is_defeated(enemy_id: int) -> bool:
	return _defeated.has(enemy_id)


func tick_respawns(delta: float) -> void:
	for id in _defeated.keys():
		_defeated[id] -= delta
		if _defeated[id] <= 0.0:
			_defeated.erase(id)
