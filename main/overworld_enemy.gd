extends Node2D

const CELL_SIZE := 32

@export var enemy_id: int = 0
@export var start_cell: Vector2i = Vector2i.ZERO

var grid_pos: Vector2i = Vector2i.ZERO

@onready var _walls: TileMapLayer = $"../Walls"


func _ready() -> void:
	grid_pos = start_cell
	_sync_position()
	$WanderTimer.timeout.connect(wander)


# Steps one tile to a random adjacent walkable cell.
func wander() -> void:
	if not visible:
		return
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	dirs.shuffle()
	for dir in dirs:
		var target: Vector2i = grid_pos + dir
		if _walls.get_cell_source_id(target) == -1:
			grid_pos = target
			_sync_position()
			return


func _sync_position() -> void:
	position = Vector2(grid_pos * CELL_SIZE) + Vector2.ONE * (CELL_SIZE / 2.0)
