extends CanvasLayer

# Overworld readout of the player's progression. Polls `Game` each frame so it
# picks up changes made in battle without any wiring.

@onready var _label: Label = $Panel/Label
@onready var _inventory_panel: PanelContainer = $Inventory
@onready var _inventory_label: Label = $Inventory/Label


func _process(_delta: float) -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_inventory_panel.visible = not _inventory_panel.visible


func refresh() -> void:
	_label.text = "HP  %d/%d\nLV  %d\nXP  %d/%d\nSCRAP  %d" % [
		Game.player_hp,
		Game.player_max_hp,
		Game.player_level,
		Game.player_xp,
		Game.xp_for_level(Game.player_level),
		Game.scrap,
	]
	if _inventory_panel.visible:
		_inventory_label.text = _inventory_text()


func _inventory_text() -> String:
	if Game.inventory.is_empty():
		return "INVENTORY (I)\n(empty)"
	var lines := ["INVENTORY (I)"]
	for item_id in Game.inventory:
		lines.append("%s  x%d" % [item_id.replace("_", " "), Game.inventory[item_id]])
	return "\n".join(lines)
