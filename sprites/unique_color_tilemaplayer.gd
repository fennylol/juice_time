extends TileMapLayer

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return 1

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:  
	tile_data.modulate =  Color.from_hsv(0.0,0.0,1.0,1.0)
