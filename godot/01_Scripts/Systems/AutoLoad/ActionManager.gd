# ActionManager.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# 턴 파이프라인의 유일한 진입점.
#   [정방향] pre_action → 게임 로직(ActionUnit 기록) → 애니메이션 재생 → commit
#   [Undo]   state 복원 → 기록된 undo_action 역산 등록 → 애니메이션 재생 → 시각 동기화
#
# 게임 로직은 AnimationQueue를 직접 알지 못한다.
# 오직 ActionManager.record()로 "무슨 일이 일어났는지"만 보고한다.
# ─────────────────────────────────────────────────────────────
extends Node


# ─────────────────────────────────────────────
# ActionUnit: 턴 중 발생한 개별 사건
# ─────────────────────────────────────────────
class ActionUnit:
	var target: Node2D
	var action: String        # 정방향 애니메이션 액션
	var data: Dictionary
	var undo_action: String   # "" 이면 undo 시 애니메이션 없음
	var undo_data: Dictionary
	var tick: int

	func _init(
		_target: Node2D,
		_tick: int,
		_action: String,
		_data: Dictionary = {},
		_undo_action: String = "",
		_undo_data: Dictionary = {}
	) -> void:
		target      = _target
		tick        = _tick
		action      = _action
		data        = _data
		undo_action = _undo_action
		undo_data   = _undo_data


# 이번 턴에 기록된 액션들 (기록 순서 보존)
var _turn_actions: Array[ActionUnit] = []

var is_turn_running := false


func _ready() -> void:
	InputManager.action_input.connect(_on_action_input)
	InputManager.back_input.connect(_on_back_input)


# ─────────────────────────────────────────────
# 게임 로직이 사건을 보고하는 유일한 창구
# ─────────────────────────────────────────────
func record(unit: ActionUnit) -> void:
	_turn_actions.append(unit)


# 편의 함수 (호출부 간결화)
func record_new(
	target: Node2D, tick: int,
	action: String, data: Dictionary = {},
	undo_action: String = "", undo_data: Dictionary = {}
) -> void:
	record(ActionUnit.new(target, tick, action, data, undo_action, undo_data))


# ─────────────────────────────────────────────
# 입력 핸들러
# ─────────────────────────────────────────────
func _on_action_input(dir: Position) -> void:
	var player = PlayerRegistry.get_player()
	if is_turn_running or AnimationQueue.is_playing: return
	if player == null or player.is_dead or player.is_fallen: return
	await run_turn(player, dir)


func _on_back_input() -> void:
	if is_turn_running or AnimationQueue.is_playing: return
	await run_undo()


# ─────────────────────────────────────────────
# 정방향 턴
# ─────────────────────────────────────────────
func run_turn(player: Player, dir: Position) -> void:
	is_turn_running = true

	# ① 턴 시작 시점 state 스냅샷
	var turn_record := UndoManager.pre_action()
	_turn_actions.clear()

	# ② 게임 로직 실행 → record()로 ActionUnit들이 쌓임
	player.action_dir(dir, 0)

	# ③ 액션 → 애니메이션 변환 등록 후 재생
	for u in _turn_actions:
		AnimationQueue.enqueue(u.target, u.action, u.data, u.tick)
	await AnimationQueue.play_all()

	# ④ 히스토리 적재
	turn_record.actions = _turn_actions.duplicate()
	_turn_actions.clear()
	UndoManager.commit_turn(turn_record)

	# ⑤ 턴 종료 후처리 (맵 전환 등)
	StageDirector.flush_pending_map_change()

	is_turn_running = false


# ─────────────────────────────────────────────
# Undo 턴 — 정방향과 동일한 파이프라인
# ─────────────────────────────────────────────
func run_undo() -> void:
	var turn_record = UndoManager.pop_record()
	if turn_record == null:
		print("ActionManager: 되돌릴 기록이 없습니다.")
		return

	is_turn_running = true

	# ① 논리 복원 (진실의 원천 = state)
	UndoManager.restore_states(turn_record)

	# ② 기록된 undo_action들을 tick 역산으로 등록
	var max_tick := 0
	for u in turn_record.actions:
		max_tick = max(max_tick, u.tick)

	for u in turn_record.actions:
		if u.undo_action == "": continue
		if not is_instance_valid(u.target): continue
		if u.target.is_queued_for_deletion(): continue
		AnimationQueue.enqueue(u.target, u.undo_action, u.undo_data, max_tick - u.tick)

	# ③ 재생 (정방향과 같은 경로)
	await AnimationQueue.play_all()

	# ④ 안전망: 애니메이션 없던 요소도 논리 상태와 화면 강제 일치
	UndoManager.sync_visuals(turn_record)

	is_turn_running = false
	print("ActionManager: Undo 완료")
