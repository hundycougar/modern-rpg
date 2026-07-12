extends Node

# Cross-scene state for the overworld <-> battle handoff. Autoloaded as `Game`.

var overworld_return_pos: Vector2i = Vector2i.ZERO
var pending_enemy_id: int = -1
var last_result: String = ""
var respawn_delay: float = 8.0

# enemy_id -> seconds left until it respawns.
var _defeated: Dictionary = {}


# Records the enemy that triggered the fight and where to put the player back.
func begin_battle(enemy_id: int, return_pos: Vector2i) -> void:
	pending_enemy_id = enemy_id
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
