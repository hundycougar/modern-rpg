# M3c acceptance test — battle skills (energy costs, cooldowns, effects).
#   godot --headless --path <repo> --script res://tests/test_m3c.gd
#
# NOTE: written without a live Godot. If a Godot 4.x API detail is off on first
# run, fix THIS file (the contract), then let the Factory build to it.
extends SceneTree

var _failed := false
var _bm

func _fail(m): print("FAIL: ", m); _failed = true
func _pass(m): print("PASS: ", m)

func _reset() -> void:
	_bm.deterministic = true
	_bm.setup_from_type("thug")

func _initialize() -> void:
	var bscene: PackedScene = load("res://battle/battle.tscn")
	if bscene == null:
		_fail("battle.tscn not found"); _finish(); return
	var battle = bscene.instantiate()
	get_root().add_child(battle)
	await process_frame
	var mgrs := get_nodes_in_group("battle")
	if mgrs.size() < 1:
		_fail("no BattleManager"); _finish(); return
	_bm = mgrs[-1]
	for m in ["available_skills", "can_use_skill", "use_skill", "tick_skill_cooldowns"]:
		if not _bm.has_method(m):
			_fail("BattleManager missing method %s" % m); _finish(); return

	# 1) three skills with expected ids
	_reset()
	var ids := []
	for s in _bm.available_skills():
		ids.append(s["id"])
	if ids.has("power_strike") and ids.has("heal") and ids.has("guard_up") and ids.size() == 3:
		_pass("three skills present: %s" % [ids])
	else:
		_fail("expected power_strike/heal/guard_up, got %s" % [ids])

	# 2) power strike damage + energy cost
	_reset()
	var enemy = _bm.enemies[0]
	var r = _bm.use_skill("power_strike", enemy)
	if r.get("ok", false) and r.get("damage", -1) == 17 and _bm.player_energy == 7:
		_pass("power_strike: 17 damage, energy 10->7")
	else:
		_fail("power_strike wrong: %s energy=%d" % [r, _bm.player_energy])

	# 3) heal caps at max hp, costs energy, then on cooldown
	_reset()
	_bm.player.hp = 25
	var h = _bm.use_skill("heal", _bm.player)
	if h.get("ok", false) and _bm.player.hp == 30 and _bm.player_energy == 5 \
			and _bm.can_use_skill("heal") == false:
		_pass("heal: capped to 30, energy 10->5, then on cooldown")
	else:
		_fail("heal wrong: hp=%d energy=%d canuse=%s"
			% [_bm.player.hp, _bm.player_energy, _bm.can_use_skill("heal")])

	# 4) guard_up buff, free, cooldown then recovers
	_reset()
	var def0 = _bm.player.defense
	var g = _bm.use_skill("guard_up", _bm.player)
	if g.get("ok", false) and _bm.player.defense == def0 + 4 and _bm.player_energy == 10 \
			and _bm.can_use_skill("guard_up") == false:
		_pass("guard_up: +4 defense, free, on cooldown")
	else:
		_fail("guard_up wrong: def %d->%d energy=%d canuse=%s"
			% [def0, _bm.player.defense, _bm.player_energy, _bm.can_use_skill("guard_up")])
	_bm.tick_skill_cooldowns(); _bm.tick_skill_cooldowns(); _bm.tick_skill_cooldowns()
	if _bm.can_use_skill("guard_up"):
		_pass("guard_up usable again after 3 cooldown ticks")
	else:
		_fail("guard_up still on cooldown after 3 ticks")

	# 5) energy gating
	_reset()
	_bm.player_energy = 1
	if _bm.can_use_skill("power_strike") == false:
		_pass("power_strike blocked when energy too low")
	else:
		_fail("power_strike should be blocked at energy 1")

	_finish()

func _finish() -> void:
	if _failed:
		print("RESULT: FAIL"); quit(1)
	else:
		print("RESULT: PASS"); quit(0)
