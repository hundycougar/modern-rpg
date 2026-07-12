extends Node2D

const CELL_SIZE := 32
const START_CELL := Vector2i(10, 10)

var grid_pos: Vector2i = START_CELL

@onready var _walls: TileMapLayer = $"../Walls"


func _ready() -> void:
	_sync_position()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("move_up"):
		try_move(Vector2i.UP)
	elif Input.is_action_just_pressed("move_down"):
		try_move(Vector2i.DOWN)
	elif Input.is_action_just_pressed("move_left"):
		try_move(Vector2i.LEFT)
	elif Input.is_action_just_pressed("move_right"):
		try_move(Vector2i.RIGHT)


# Moves one tile in `dir` if the target tile is walkable. Returns whether it moved.
func try_move(dir: Vector2i) -> bool:
	var target := grid_pos + dir
	if _walls.get_cell_source_id(target) != -1:
		return false
	grid_pos = target
	_sync_position()
	return true


func _sync_position() -> void:
	# Centre the sprite in its cell.
	position = Vector2(grid_pos * CELL_SIZE) + Vector2.ONE * (CELL_SIZE / 2.0)
