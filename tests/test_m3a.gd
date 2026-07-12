# M3a acceptance test — persistent player state + battle HP application.
#   godot --headless --path <repo> --script res://tests/test_m3a.gd
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _initialize() -> void:
	# --- GameManager persistence ---
	var gm = load("res://game/game_manager.gd").new()

	if gm.player_hp == 30 and gm.player_max_hp == 30:
		_pass("fresh player at full HP (30/30)")
	else:
		_fail("expected 30/30, got %d/%d" % [gm.player_hp, gm.player_max_hp])

	gm.set_player_hp(12)
	if gm.player_hp == 12:
		_pass("set_player_hp persists 12")
	else:
		_fail("expected player_hp 12, got %d" % gm.player_hp)

	gm.set_player_hp(999)
	if gm.player_hp == 30:
		_pass("set_player_hp clamps to max")
	else:
		_fail("expected clamp to 30, got %d" % gm.player_hp)

	gm.set_player_hp(-5)
	if gm.player_hp == 0 and gm.is_game_over():
		_pass("0 HP -> game over")
	else:
		_fail("expected 0 HP + game_over (hp=%d over=%s)" % [gm.player_hp, gm.is_game_over()])

	gm.reset_player()
	if gm.player_hp == 30 and not gm.is_game_over():
		_pass("reset_player restores full HP, clears game over")
	else:
		_fail("expected reset to 30 and not over (hp=%d over=%s)" % [gm.player_hp, gm.is_game_over()])

	# --- Battle applies persistent HP ---
	var bscene: PackedScene = load("res://battle/battle.tscn")
	if bscene == null:
		_fail("battle.tscn not found"); _finish(); return
	var battle = bscene.instantiate()
	get_root().add_child(battle)
	await process_frame
	var mgrs := get_nodes_in_group("battle")
	if mgrs.size() < 1:
		_fail("no BattleManager in group 'battle'"); _finish(); return
	var bm = mgrs[-1]

	if not bm.has_method("apply_player_stats") or not bm.has_method("player_current_hp"):
		_fail("battle missing apply_player_stats / player_current_hp"); _finish(); return

	bm.deterministic = true
	bm.setup_from_type("thug")
	bm.apply_player_stats(15, 30, 10, 2, 8)
	if bm.player_current_hp() == 15 and bm.player.max_hp == 30:
		_pass("battle applies carried-over player HP (15/30)")
	else:
		_fail("expected 15/30 after apply, got %d/%d" % [bm.player_current_hp(), bm.player.max_hp])

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
