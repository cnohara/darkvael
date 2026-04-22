@tool
extends SceneTree

const MAP_TILE_DATA := preload("res://map_tile_data.gd")

func _initialize() -> void:
	for tile_id in MAP_TILE_DATA.get_tile_ids():
		var tile = MAP_TILE_DATA.instantiate_tile(String(tile_id))
		if tile == null:
			push_error("Could not instantiate map tile %s" % tile_id)
			quit(1)
			return
		var data: Dictionary = tile.to_tile_dict()
		print("%s obstacles=%d exits=%d torches=%d" % [
			data.get("id", ""),
			data.get("obstacles", []).size(),
			data.get("exits", []).size(),
			data.get("torches", []).size(),
		])
		tile.free()
	quit(0)
