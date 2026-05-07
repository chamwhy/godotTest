# Position.gd
extends Resource
class_name Position # 전역에서 'Position' 타입으로 인식되도록 설정


# y 픽셀 비율
const px = 32
const py = 24
const pypx = 0.75


# 기본 데이터: x, y
var x: int = 0
var y: int = 0


#region --- 정적 상수 제공 함수 ---

static func ZERO() -> Position:
	return Position.new(0, 0)

static func UP() -> Position:
	return Position.new(0, -1)

static func DOWN() -> Position:
	return Position.new(0, 1)

static func LEFT() -> Position:
	return Position.new(-1, 0)

static func RIGHT() -> Position:
	return Position.new(1, 0)
#endregion



## --- 2. 초기화 (편의를 위한 생성자) ---
func _init(new_x: int = 0, new_y: int = 0):
	self.x = new_x
	self.y = new_y

## --- 3. Vector2와의 상호 운용성 ---
# Vector2 타입으로 변환하는 함수 (Godot 내장 기능과의 호환성 확보)
func to_vector2() -> Vector2:
	return Vector2(x, y * py / px)

static func position_to_world(pos: Position) -> Vector2:
	# TODO: 나중에 카메라 관련 기획짜서 고치기?
	return Vector2((pos.x + 0.5) * MapDrawer.tile_size_x, (pos.y + 0.5) * MapDrawer.tile_size_y) 

# Vector2에서 Position을 생성하는 static 함수
static func from_vector2(vector: Vector2) -> Position:
	return Position.new(int(vector.x), int(vector.y * px / py))

## --- 4. 각종 함수 ---

func copy() -> Position:
	return Position.new(x, y)

func is_zero() -> bool:
	return x == 0 and y == 0
# 직선 이동인지 판단하는 함수
func is_straight() -> bool:
	return x == 0 or y == 0

func normalized() -> Position:
	return Position.new(sign(x), sign(y))

## --- 5. 추가 연산 구현 ---

# 덧셈 연산 (Position + Position)
func add(other: Position) -> Position:
	# 새로운 Position 객체를 반환하여 원본 객체의 불변성을 유지하는 것이 좋습니다.
	return Position.new(x + other.x, y + other.y)

# 뺄셈 연산 (Position - Position)
func subtract(other: Position) -> Position:
	return Position.new(x - other.x, y - other.y)

func multiply(multiplier: int) -> Position:
	return Position.new(x * multiplier, y * multiplier)


# 비교 연산 (==)
func equals(other: Position) -> bool:
	if other == null:
		return false
	return x == other.x and y == other.y


#region overloading
# 덧셈 연산자 오버로딩 (pos1 + pos2)
func _add(other: Position) -> Position:
	return add(other) # 위에 정의한 add 함수 재활용

# 뺄셈 연산자 오버로딩 (pos1 - pos2)
func _sub(other: Position) -> Position:
	return subtract(other)

# 비교 연산자 오버로딩 (pos1 == pos2)
func _eq(other: Position) -> bool:
	return equals(other)
#endregion


#region util
func to_str() -> String:
	return "Position(%d, %d)" % [x, y]
#endregion
