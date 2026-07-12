# M2.2 acceptance test — the touched mob's type defines the fight, with variance.
#   godot --headless --path <repo> --script res://tests/test_m22.gd
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _check_stats(e, hp, atk, dfn, agi, label) -> void:
	if e.max_hp == hp and e.attack == atk and e.defense == dfn and e.agility == agi:
		_pass("%s base stats correct" % label)
	else:
		_fail("%s stats wrong: got %d/%d/%d/%d expected %d/%d/%d/%d"
			% [label, e.max_hp, e.attack, e.defense, e.agility, hp, atk, dfn, agi])

func _initialize() -> void:
	# --- overworld enemies expose a type ---
	var wscene: PackedScene = load("res://main/world.tscn")
	if wscene == null:
		_fail("world.tscn not found"); _finish(); return
	var world = wscene.instantiate()
	get_root().add_child(world)
	await process_frame
	var oes := get_nodes_in_group("overworld_enemy")
	if oes.size() >= 1 and ("enemy_type" in oes[0]) and oes[0].enemy_type in ["thug", "drone"]:
		_pass("overworld enemies expose enemy_type")
	else:
		_fail("overworld enemies must expose enemy_type in {thug,drone}")

	# --- battle builds from type ---
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
	if not bm.has_method("setup_from_type"):
		_fail("BattleManager has no setup_from_type()"); _finish(); return

	bm.deterministic = true

	bm.setup_from_type("thug")
	if bm.enemies.size() == 1:
		_pass("thug encounter -> single enemy")
		_check_stats(bm.enemies[0], 12, 6, 1, 5, "thug")
	else:
		_fail("expected 1 enemy for thug, got %d" % bm.enemies.size())

	bm.setup_from_type("drone")
	if bm.enemies.size() == 1:
		_pass("drone encounter -> single enemy")
		_check_stats(bm.enemies[0], 10, 5, 3, 7, "drone")
	else:
		_fail("expected 1 enemy for drone, got %d" % bm.enemies.size())

	# --- variance within range ---
	bm.deterministic = false
	var ok := true
	for i in range(8):
		bm.setup_from_type("thug")
		var e = bm.enemies[0]
		if e.max_hp < 10 or e.max_hp > 14 or e.attack < 5 or e.attack > 7:
			ok = false
			_fail("variance out of range: hp=%d atk=%d" % [e.max_hp, e.attack])
			break
	if ok:
		_pass("thug variance stays in range across setups")

	# --- GameManager carries the type ---
	var gm = load("res://game/game_manager.gd").new()
	gm.begin_battle(7, Vector2i(10, 10), "drone")
	if gm.pending_enemy_type == "drone":
		_pass("begin_battle records enemy type")
	else:
		_fail("expected pending_enemy_type 'drone', got %s" % gm.pending_enemy_type)

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
