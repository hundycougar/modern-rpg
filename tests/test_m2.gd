# M2 acceptance test — the battle-logic oracle. Run headless:
#   godot --headless --path <repo> --script res://tests/test_m2.gd
# Prints PASS:/FAIL: and exits 0 only if every check passes.
#
# NOTE: written without a live Godot to run against. If a Godot 4.x API detail is
# off on first run, fix THIS file (it's the contract), then let the Factory build
# the battle to satisfy it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _find_enemy(bm, want_agility):
	for e in bm.enemies:
		if e.agility == want_agility:
			return e
	return null

func _initialize() -> void:
	var scene: PackedScene = load("res://battle/battle.tscn")
	if scene == null:
		_fail("res://battle/battle.tscn not found"); _finish(); return
	var root = scene.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var mgrs := get_nodes_in_group("battle")
	if mgrs.size() != 1:
		_fail("expected 1 node in group 'battle', found %d" % mgrs.size()); _finish(); return
	var bm = mgrs[0]
	_pass("found BattleManager")

	bm.deterministic = true

	# 2) turn order by agility desc: player(8), drone(7), thug(5)
	var order = bm.turn_order()
	var ags := []
	for c in order:
		ags.append(c.agility)
	var sorted_desc := ags.duplicate()
	sorted_desc.sort()
	sorted_desc.reverse()
	if ags == sorted_desc and ags.size() >= 3:
		_pass("turn order sorted by agility desc %s" % [ags])
	else:
		_fail("turn order not agility-desc: %s" % [ags])

	# 3) deterministic damage: player(atk10) vs thug(def1) = 9
	var thug = _find_enemy(bm, 5)
	if thug == null:
		_fail("could not find thug (agility 5)"); _finish(); return
	var hp_before: int = thug.hp
	var dmg: int = bm.do_attack(bm.player, thug)
	if dmg == 9 and thug.hp == hp_before - 9:
		_pass("deterministic damage = 9")
	else:
		_fail("expected 9 damage (hp %d->%d), got dmg=%d hp=%d"
			% [hp_before, hp_before - 9, dmg, thug.hp])

	# 7) defending halves damage
	thug.defending = true
	var d2: int = bm.do_attack(bm.player, thug)
	if d2 == 4 or d2 == 5:   # 9 halved -> 4 (int) ; allow 5 if they round up
		_pass("defend halves damage (%d)" % d2)
	else:
		_fail("expected ~4-5 damage while defending, got %d" % d2)
	thug.defending = false

	# 4/5) kill all enemies -> player wins
	for e in bm.enemies:
		while e.is_alive():
			bm.do_attack(bm.player, e)
	if not bm.enemies[0].is_alive():
		_pass("dead combatant reports not alive")
	else:
		_fail("combatant at 0 hp still alive")
	if bm.is_over() and bm.winner() == "player":
		_pass("all enemies dead -> player wins")
	else:
		_fail("expected player win (over=%s winner=%s)" % [bm.is_over(), bm.winner()])

	# 6) fresh battle, kill the player -> enemies win
	var root2 = scene.instantiate()
	get_root().add_child(root2)
	await process_frame
	var bm2 = get_nodes_in_group("battle")[-1]
	bm2.deterministic = true
	while bm2.player.is_alive():
		bm2.do_attack(bm2.enemies[0], bm2.player)
	if bm2.is_over() and bm2.winner() == "enemies":
		_pass("player dead -> enemies win")
	else:
		_fail("expected enemies win (over=%s winner=%s)" % [bm2.is_over(), bm2.winner()])

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
