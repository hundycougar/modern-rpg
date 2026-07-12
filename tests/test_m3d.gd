# M3d acceptance test — scrap + item loot drops.
#   godot --headless --path <repo> --script res://tests/test_m3d.gd
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _gm():
	return load("res://game/game_manager.gd").new()

func _initialize() -> void:
	var gm = _gm()

	# 1) fresh
	if gm.scrap == 0 and gm.inventory.is_empty():
		_pass("fresh: 0 scrap, empty inventory")
	else:
		_fail("expected empty loot, got scrap=%d inv=%s" % [gm.scrap, gm.inventory])

	# 2) scrap adds
	gm.add_scrap(10); gm.add_scrap(5)
	if gm.scrap == 15:
		_pass("add_scrap accumulates to 15")
	else:
		_fail("expected scrap 15, got %d" % gm.scrap)

	# 3) item counts
	gm.add_item("bandage", 2); gm.add_item("bandage")
	if gm.item_count("bandage") == 3 and gm.item_count("nope") == 0:
		_pass("item_count tracks quantities")
	else:
		_fail("expected bandage 3 / nope 0, got %d / %d"
			% [gm.item_count("bandage"), gm.item_count("nope")])

	# 4) loot tables
	var t = gm.loot_table("thug")
	var d = gm.loot_table("drone")
	if t["scrap_min"] == 5 and t["scrap_max"] == 15 and t["common"]["id"] == "bandage" \
			and t["rare"]["id"] == "stimpack" and d["scrap_min"] == 8 and d["scrap_max"] == 20:
		_pass("loot tables correct for thug & drone")
	else:
		_fail("loot tables wrong: thug=%s drone=%s" % [t, d])

	# 5) resolve_loot is deterministic given rolls
	var r_none = gm.resolve_loot("thug", 0.0, 0.99)
	var r_rare = gm.resolve_loot("thug", 1.0, 0.02)
	var r_common = gm.resolve_loot("thug", 0.5, 0.30)
	if r_none["scrap"] == 5 and r_none["item"] == "" \
			and r_rare["scrap"] == 15 and r_rare["item"] == "stimpack" \
			and r_common["scrap"] == 10 and r_common["item"] == "bandage":
		_pass("resolve_loot maps rolls -> scrap/item correctly")
	else:
		_fail("resolve_loot wrong: none=%s rare=%s common=%s" % [r_none, r_rare, r_common])

	# 6) winning a fight awards at least the minimum scrap
	var gm2 = _gm()
	gm2.begin_battle(1, Vector2i(0, 0), "thug")
	gm2.end_battle("player")
	if gm2.scrap >= 5:
		_pass("winning drops scrap (got %d)" % gm2.scrap)
	else:
		_fail("expected >=5 scrap after win, got %d" % gm2.scrap)

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
