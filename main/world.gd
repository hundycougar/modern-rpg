extends Node2D

const MAP_SIZE := 100
const FLOOR_SOURCE := 0
const WALL_SOURCE := 1
const ATLAS_COORDS := Vector2i.ZERO

const BATTLE_SCENE := "res://battle/battle.tscn"

# The fixture the acceptance test relies on: a lone wall directly above the
# player's (10,10) start.
const FIXTURE_WALL := Vector2i(10, 9)

@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls
@onready var _player = $Player

# An encounter can only fire once the player is clear of every enemy, so we don't
# re-enter the battle we just fled or lost on the tile we came back to.
var _armed := true


func _ready() -> void:
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			_floor.set_cell(Vector2i(x, y), FLOOR_SOURCE, ATLAS_COORDS)

	for i in MAP_SIZE:
		_set_wall(Vector2i(i, 0))
		_set_wall(Vector2i(i, MAP_SIZE - 1))
		_set_wall(Vector2i(0, i))
		_set_wall(Vector2i(MAP_SIZE - 1, i))

	_set_wall(FIXTURE_WALL)

	if Game.last_result != "":
		_player.set_grid_pos(Game.overworld_return_pos)
		_armed = false

	_refresh_enemies()


func _process(delta: float) -> void:
	Game.tick_respawns(delta)
	_refresh_enemies()

	var id := check_encounter()
	if id == -1:
		_armed = true
	elif _armed:
		_armed = false
		Game.begin_battle(id, _player.grid_pos)
		get_tree().change_scene_to_file(BATTLE_SCENE)


# The id of a live overworld enemy sharing the player's tile or an orthogonally
# adjacent one, else -1.
func check_encounter() -> int:
	for e in get_tree().get_nodes_in_group("overworld_enemy"):
		if not e.visible:
			continue
		var offset: Vector2i = e.grid_pos - _player.grid_pos
		if absi(offset.x) + absi(offset.y) <= 1:
			return e.enemy_id
	return -1


# Defeated enemies stay hidden until their respawn timer runs out.
func _refresh_enemies() -> void:
	for e in get_tree().get_nodes_in_group("overworld_enemy"):
		e.visible = not Game.is_defeated(e.enemy_id)


func _set_wall(cell: Vector2i) -> void:
	_walls.set_cell(cell, WALL_SOURCE, ATLAS_COORDS)
