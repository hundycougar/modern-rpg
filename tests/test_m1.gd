# M1 acceptance test — the QA oracle. Run headless:
#   godot --headless --path <repo> --script res://tests/test_m1.gd
# Prints PASS:/FAIL: lines and exits 0 only if every check passes.
#
# NOTE: written without a live Godot to run against — if a Godot 4.x API detail is
# off on first run, fix THIS file (it is the contract), then let the Factory build
# the game to satisfy it.
extends SceneTree

var _failed := false

func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failed = true

func _pass(msg: String) -> void:
	print("PASS: ", msg)

func _initialize() -> void:
	var scene: PackedScene = load("res://main/world.tscn")
	if scene == null:
		_fail("res://main/world.tscn not found")
		_finish()
		return
	var world := scene.instantiate()
	get_root().add_child(world)
	# let _ready run
	await process_frame
	await process_frame

	var players := get_nodes_in_group("player")
	if players.size() != 1:
		_fail("expected exactly 1 node in group 'player', found %d" % players.size())
		_finish()
		return
	var player := players[0]
	_pass("found single player node")

	if not ("grid_pos" in player):
		_fail("player has no 'grid_pos' property")
		_finish()
		return
	if not player.has_method("try_move"):
		_fail("player has no 'try_move' method")
		_finish()
		return
	_pass("player exposes grid_pos and try_move")

	# Fixture (see work order): player starts at (10,10); a wall sits directly
	# above at (10,9); (11,10) to the right is open.
	var start: Vector2i = player.grid_pos
	if start != Vector2i(10, 10):
		_fail("expected player to start at (10,10), got %s" % start)
		_finish()
		return
	_pass("player starts at fixture tile (10,10)")

	# 4) wall blocks — the tile above the start is impassable
	var into_wall: bool = player.try_move(Vector2i.UP)
	if not into_wall and player.grid_pos == start:
		_pass("wall blocks movement")
	else:
		_fail("expected UP into wall at (10,9) to be blocked (now=%s moved=%s)"
			% [player.grid_pos, into_wall])

	# 3) move into open space
	var moved: bool = player.try_move(Vector2i.RIGHT)
	if moved and player.grid_pos == start + Vector2i.RIGHT:
		_pass("moved right into open tile")
	else:
		_fail("expected move RIGHT to succeed and increment grid_pos.x (start=%s now=%s moved=%s)"
			% [start, player.grid_pos, moved])

	# 5) map edge blocks — walk to the left wall then try to leave
	for _i in range(200):
		if not player.try_move(Vector2i.LEFT):
			break
	var at_edge: Vector2i = player.grid_pos
	var left_off: bool = player.try_move(Vector2i.LEFT)
	if not left_off and player.grid_pos == at_edge:
		_pass("map edge blocks movement")
	else:
		_fail("expected LEFT past edge to be blocked (at=%s moved=%s)" % [at_edge, left_off])

	# 6) input: move_* actions must map BOTH the WASD key and the arrow key
	var expected := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
	}
	for action in expected:
		var keys := _action_keys(action)
		var need: Array = expected[action]
		if keys.has(need[0]) and keys.has(need[1]):
			_pass("input '%s' maps both keys" % action)
		else:
			_fail("input '%s' must map keys %s (found %s)" % [action, need, keys])

	_finish()

func _action_keys(action: String) -> Array:
	var out := []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.keycode)
			out.append(ev.physical_keycode)
	return out

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
