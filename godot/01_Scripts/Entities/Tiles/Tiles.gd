# Tile.gd
# 움직이거나 규칙에 영향을 받지 않는 고정된 배경 요소 (선택 사항)
extends Entity
class_name Tile

var tile_id: int	# 해당 타일 id
var preset: TilePreset  # 해당 타일 프리셋


func apply_data(data: Dictionary):
	super.apply_data(data)
	z_index = ZIndexer.calc(cur_position.y, ZIndexer.ZID_TILE)
	print("tile apply data")
	tile_id = data.get("id", 1)	# tile id는 기본이 1, 0은 없음을 나타냄.
	InGameManager.register_tile(cur_position, tile_id)
	# TODO: id에 따라 preset 가져오기 + preset에 따라 타일 리셋
	
