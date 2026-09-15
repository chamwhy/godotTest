extends Camera2D
class_name MyCamera

static var instance: MyCamera

func _enter_tree():
	instance = self

# 맵 크기에 맞춰 위치와 줌을 "즉시" 설정
func setup_map(tile_size_x: int, tile_size_y: int, width: int, height: int, zoom_f: float = 0, offset_px: Vector2 = Vector2.ZERO, margin: float = 1):
	var map_pixel_size = Vector2(width * tile_size_x, height * tile_size_y)
	
	# 줌 먼저 계산 (offset 보정에 필요)
	var zoom_factor = zoom_f
	if zoom_factor == 0:
		var screen_size = get_viewport().get_visible_rect().size
		zoom_factor = min(screen_size.x / (map_pixel_size.x * margin), screen_size.y / (map_pixel_size.y * margin))
	zoom = Vector2(zoom_factor, zoom_factor)
	
	# 중앙 + offset
	position = (map_pixel_size * 0.5 + offset_px).round()
	
	print("cam setting - pos: ", position, ", zoom: ", zoom_factor, ", offset: ", offset_px)
