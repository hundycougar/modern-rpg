extends Node2D

const MAP_SIZE := 100
const FLOOR_SOURCE := 0
const WALL_SOURCE := 1
const ATLAS_COORDS := Vector2i.ZERO

# The fixture the acceptance test relies on: a lone wall directly above the
# player's (10,10) start.
const FIXTURE_WALL := Vector2i(10, 9)

@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls


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


func _set_wall(cell: Vector2i) -> void:
	_walls.set_cell(cell, WALL_SOURCE, ATLAS_COORDS)
