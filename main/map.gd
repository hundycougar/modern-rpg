# Shared map constants + the runtime-generated placeholder TileSet.
#
# The TileSet is built in code (not committed as art) so world.tscn has no
# import-dependent external resources — it instantiates cleanly under
# `godot --headless` even if the asset import step hasn't run.
#
# Deliberately no `class_name`: a global class name only resolves via the
# import-time class cache, which does not exist when the acceptance test is run
# with `godot --headless --script` on a fresh checkout. Consumers preload this.
extends Object

const TILE_SIZE := 16
const SIZE := Vector2i(100, 100)

## Atlas source id, and the two atlas coords in the generated tile sheet.
const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)

static func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < SIZE.x and tile.y < SIZE.y

## A 2-tile sheet: grey floor at (0,0), red wall at (1,0).
static func make_tileset() -> TileSet:
	var image := Image.create(TILE_SIZE * 2, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Color(0.24, 0.27, 0.31))
	image.fill_rect(Rect2i(TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), Color(0.65, 0.22, 0.22))

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(FLOOR)
	source.create_tile(WALL)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, SOURCE_ID)
	return tile_set
