# AutoLoad
extends Node

const MOVE_DELAY := 0.8
@onready var player: Player = $Player


# 현재 플레이어가 행동하는지 지 여부(딜레이를 주기 위하여)
var is_act: bool = true

func _ready() -> void:
	InputManager.action_input.connect(_action_inputed)
	
func _action_inputed(dir: Position):
	if is_act: return
	player.action_dir(dir)
	
#region Map
#region Mapping
var tile_map: Array = []
var element_map: Array = []
var map_width: int
var map_height: int

func init(width, height):
	map_width = width
	map_height = height
	tile_map.resize(height)
	element_map.resize(height)
	
	for y in range(height):
		tile_map[y] = []
		element_map[y] = []
		for x in range(width):
			tile_map[x].append(0)
			element_map[x].append([])

func map_size_in(x:int, y:int) -> bool:
	return 0 <= x and x < map_width and 0 <= y and y < map_height

func has_tile(x:int, y:int) -> bool:
	if not map_size_in(x, y): return false
	return tile_map[y][x] != 0

func register_tile(pos: Position, tile_id: int) -> void:
	if not has_tile(pos.x, pos.y): return
	tile_map[pos.y][pos.x] = tile_id
	
func register_element(pos: Position, elm: Element) -> void:
	if not has_tile(pos.x, pos.y): return
	if element_map[pos.y][pos.x] == null:
		element_map[pos.y][pos.x] = [elm]
	else:
		element_map[pos.y][pos.x].append(elm)

# filter - 0: none, 1: hitable
func get_element(pos: Position, filter: int) -> Element:
	if not has_tile(pos.x, pos.y): return null
	if element_map[pos.y][pos.x] == null: return null
	
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i]
		if not re is Element: continue
		if filter == 1:
			if not re.hitable: continue
		element_map[pos.y][pos.x].remove(i)
		return re
	return null


## map enter, pass, exit signal
signal element_entered(pos: Position, elm: Element, tick: int)
signal element_passed(pos: Position, elm: Element, tick: int)
signal element_exited(pos: Position, elm: Element, tick: int)


# Element 넣기(register는 등록만, 해당 함수는 외부 처리까지 동시에 진행)
func enter_element(elm: Element, pos: Position, tick: int) -> bool:
	if not has_tile(pos.x, pos.y): return false
	
	register_element(pos, elm)
	element_entered.emit(pos, elm, tick)
	
	return true


func pass_element(elm: Element, pos: Position, tick: int) -> bool:
	if not has_tile(pos.x, pos.y): return false
	element_passed.emit(pos, elm, tick)
	
	return true

# 일치하는 Element 꺼내기
func exit_element(elm: Element, pos: Position, tick: int) -> Element:
	if not has_tile(pos.x, pos.y): return null
	if element_map[pos.y][pos.x] == null: return null
	
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i]
		if not re is Element: continue
		if re != elm: continue
		element_map[pos.y][pos.x].remove(i)
		element_exited.emit(pos, elm, tick)
		return re
	return null


#endregion


func entity_exit(pos: Position, ent: Entity) -> void:
	pass

func entity_pass(pos: Position, ent: Entity) -> void:
	pass

func entity_placed(pos: Position, ent: Entity) -> void:
	pass

# 지나갈 수 있는 지 여부
func can_pass(pos: Position) -> bool:
	return true

# 놓일 수 있는 지 여부
func can_placed(pos: Position) -> bool:
	return true


#endregion

#region MapPosition
func position_to_world(pos: Position) -> Vector2:
	return Vector2(pos.x + 0.5, pos.y + 0.5) * MapDrawer.tile_size

#endregion
