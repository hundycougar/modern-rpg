extends CanvasLayer

# Overworld readout of the player's progression. Polls `Game` each frame so it
# picks up changes made in battle without any wiring.

@onready var _label: Label = $Panel/Label


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	_label.text = "HP  %d/%d\nLV  %d\nXP  %d/%d" % [
		Game.player_hp,
		Game.player_max_hp,
		Game.player_level,
		Game.player_xp,
		Game.xp_for_level(Game.player_level),
	]
