# M3b acceptance test — XP curve, leveling, stat growth, battle XP rewards.
#   godot --headless --path <repo> --script res://tests/test_m3b.gd
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _gm():
	return load("res://game/game_manager.gd").new()

func _stats(gm) -> String:
	return "%d/%d/%d/%d" % [gm.player_max_hp, gm.player_attack, gm.player_defense, gm.player_agility]

func _initialize() -> void:
	var gm = _gm()

	if gm.player_level == 1 and gm.player_xp == 0:
		_pass("fresh player at level 1, 0 xp")
	else:
		_fail("expected L1/0xp, got L%d/%dxp" % [gm.player_level, gm.player_xp])

	# XP curve exact integers
	var c1 = gm.xp_for_level(1)
	var c2 = gm.xp_for_level(2)
	var c3 = gm.xp_for_level(3)
	if c1 == 75 and c2 == 191 and c3 == 335:
		_pass("xp curve = 75 / 191 / 335")
	else:
		_fail("xp curve wrong: %d / %d / %d (want 75/191/335)" % [c1, c2, c3])

	# single level up + heal-on-levelup
	gm.set_player_hp(5)
	var gained = gm.gain_xp(75)
	if gained == 1 and gm.player_level == 2 and gm.player_xp == 0 \
			and _stats(gm) == "35/12/3/9" and gm.player_hp == 35:
		_pass("level 1->2 grows stats and full-heals (35/12/3/9, hp 35)")
	else:
		_fail("level up wrong: gained=%d L%d xp=%d stats=%s hp=%d"
			% [gained, gm.player_level, gm.player_xp, _stats(gm), gm.player_hp])

	# multi-level up carries remainder
	var gm2 = _gm()
	var g2 = gm2.gain_xp(300)
	if g2 == 2 and gm2.player_level == 3 and gm2.player_xp == 34 and _stats(gm2) == "40/14/4/10":
		_pass("gain_xp(300) -> L3, 34xp, stats 40/14/4/10")
	else:
		_fail("multi-levelup wrong: gained=%d L%d xp=%d stats=%s"
			% [g2, gm2.player_level, gm2.player_xp, _stats(gm2)])

	# battle XP rewards by type
	var gm3 = _gm()
	gm3.begin_battle(1, Vector2i(0, 0), "thug")
	gm3.end_battle("player")
	var gm4 = _gm()
	gm4.begin_battle(2, Vector2i(0, 0), "drone")
	gm4.end_battle("player")
	if gm3.player_xp == 30 and gm4.player_xp == 40:
		_pass("winning awards XP by type (thug 30, drone 40)")
	else:
		_fail("battle xp wrong: thug=%d drone=%d (want 30/40)" % [gm3.player_xp, gm4.player_xp])

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
