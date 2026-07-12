# Builds the 100x100 vertical-slice map: a full floor layer plus a wall layer.
# A cell present in the Walls layer is impassable (see Player.try_move).
extends Node2D

const Map := preload("res://main/map.gd")

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls

func _ready() -> void:
	var tile_set := Map.make_tileset()
	ground.tile_set = tile_set
	walls.tile_set = tile_set
	_paint_ground()
	_paint_walls()

func _paint_ground() -> void:
	for y in Map.SIZE.y:
		for x in Map.SIZE.x:
			ground.set_cell(Vector2i(x, y), Map.SOURCE_ID, Map.FLOOR)

func _paint_walls() -> void:
	# Impassable outer border.
	for x in Map.SIZE.x:
		_wall(Vector2i(x, 0))
		_wall(Vector2i(x, Map.SIZE.y - 1))
	for y in Map.SIZE.y:
		_wall(Vector2i(0, y))
		_wall(Vector2i(Map.SIZE.x - 1, y))

	# M1 test fixture: a wall directly above the player's start tile (10,10).
	_wall(Vector2i(10, 9))

func _wall(tile: Vector2i) -> void:
	walls.set_cell(tile, Map.SOURCE_ID, Map.WALL)
