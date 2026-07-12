# Grid-snapped player. Movement is one tile at a time, blocked by wall cells and
# by the map edges.
extends Node2D

const Map := preload("res://main/map.gd")

@export var walls_path: NodePath
@export var start_tile := Vector2i(10, 10)

## Current tile coordinate, 0..99 on each axis.
var grid_pos: Vector2i

@onready var _walls: TileMapLayer = get_node(walls_path)

func _ready() -> void:
	grid_pos = start_tile
	position = _tile_to_world(grid_pos)

func _process(_delta: float) -> void:
	for action in _INPUT_DIRS:
		if Input.is_action_just_pressed(action):
			try_move(_INPUT_DIRS[action])
			return

const _INPUT_DIRS := {
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
}

## Move one tile in `dir`. Returns true if the move happened, false if blocked
## by a wall or the map edge.
func try_move(dir: Vector2i) -> bool:
	var target := grid_pos + dir
	if not _is_passable(target):
		return false
	grid_pos = target
	position = _tile_to_world(grid_pos)
	return true

func _is_passable(tile: Vector2i) -> bool:
	if not Map.in_bounds(tile):
		return false
	return _walls.get_cell_source_id(tile) == -1

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile * Map.TILE_SIZE) + Vector2.ONE * (Map.TILE_SIZE * 0.5)
