# M2.1 acceptance test — overworld encounter + battle-transition bookkeeping.
#   godot --headless --path <repo> --script res://tests/test_m21.gd
# Tests the LOGIC (encounter detection, defeat/respawn state). The actual scene
# swap and feel are verified by a human at the gate.
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _initialize() -> void:
	# --- Overworld: enemies + encounter detection ---
	var scene: PackedScene = load("res://main/world.tscn")
	if scene == null:
		_fail("res://main/world.tscn not found"); _finish(); return
	var world = scene.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame

	var players := get_nodes_in_group("player")
	if players.size() != 1:
		_fail("expected 1 player, found %d" % players.size()); _finish(); return
	var player = players[0]

	var enemies := get_nodes_in_group("overworld_enemy")
	if enemies.size() >= 1:
		_pass("found %d overworld enemies" % enemies.size())
	else:
		_fail("expected >=1 nodes in group 'overworld_enemy'"); _finish(); return

	var e0 = enemies[0]
	if not ("enemy_id" in e0) or not ("grid_pos" in e0) or not e0.has_method("wander"):
		_fail("overworld enemy missing enemy_id / grid_pos / wander()"); _finish(); return
	_pass("overworld enemy exposes enemy_id, grid_pos, wander()")

	if not world.has_method("check_encounter"):
		_fail("world has no check_encounter() method"); _finish(); return

	# park every enemy far away, put player somewhere clear -> no encounter
	var slot := 0
	for e in enemies:
		e.grid_pos = Vector2i(60 + slot, 60)
		slot += 1
	player.grid_pos = Vector2i(5, 5)
	if world.check_encounter() == -1:
		_pass("no encounter when player is far from all enemies")
	else:
		_fail("expected -1 encounter when player far, got %d" % world.check_encounter())

	# put the player on e0's tile -> encounter returns e0's id
	player.grid_pos = e0.grid_pos
	var enc: int = world.check_encounter()
	if enc == e0.enemy_id:
		_pass("encounter returns the touched enemy's id")
	else:
		_fail("expected encounter id %d, got %d" % [e0.enemy_id, enc])

	# --- GameManager: transition + respawn bookkeeping (standalone instance) ---
	var gm_script = load("res://game/game_manager.gd")
	if gm_script == null:
		_fail("res://game/game_manager.gd not found"); _finish(); return
	var gm = gm_script.new()

	gm.begin_battle(7, Vector2i(10, 10))
	if gm.pending_enemy_id == 7 and gm.overworld_return_pos == Vector2i(10, 10):
		_pass("begin_battle records enemy id + return position")
	else:
		_fail("begin_battle bookkeeping wrong (id=%s pos=%s)"
			% [gm.pending_enemy_id, gm.overworld_return_pos])

	gm.end_battle("player")
	if gm.last_result == "player" and gm.is_defeated(7):
		_pass("winning marks the enemy defeated")
	else:
		_fail("expected win to defeat enemy 7 (result=%s defeated=%s)"
			% [gm.last_result, gm.is_defeated(7)])

	gm.tick_respawns(gm.respawn_delay + 1.0)
	if not gm.is_defeated(7):
		_pass("enemy respawns after respawn_delay")
	else:
		_fail("enemy 7 should have respawned after delay")

	gm.begin_battle(9, Vector2i(3, 3))
	gm.end_battle("enemies")
	if not gm.is_defeated(9):
		_pass("losing does NOT defeat the enemy")
	else:
		_fail("losing should not mark enemy 9 defeated")

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
