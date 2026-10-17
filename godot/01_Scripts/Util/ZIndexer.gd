# ZIndexer.gd (AutoLoad 또는 static 유틸)
class_name ZIndexer

# ZID 상수 정의
const ZID_TILE = 0
const ZID_ELEMENT = 1
const ZID_EFFECT = 2

# Y당 ZID 슬롯 간격 (ZID 최대값보다 크게)
const Y_STRIDE = 10

static func calc(y: int, zid: int) -> int:
	return y * Y_STRIDE + zid
