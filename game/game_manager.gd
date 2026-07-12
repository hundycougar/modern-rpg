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


func is_defeated(enemy_id: int) -> bool:
	return _defeated.has(enemy_id)


func tick_respawns(delta: float) -> void:
	for id in _defeated.keys():
		_defeated[id] -= delta
		if _defeated[id] <= 0.0:
			_defeated.erase(id)
