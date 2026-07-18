# PlayerRegistry.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# 플레이어 인스턴스의 등록과 "생기면 실행해줘" 콜백 대기열.
# ─────────────────────────────────────────────────────────────
extends Node

signal player_registered(player: Player)

var _player: Player = null
var _pending_callbacks: Array[Callable] = []


func get_player() -> Player:
	return _player


func register_player(player_node: Player) -> void:
	_player = player_node
	print("플레이어 등록")
	for callback in _pending_callbacks:
		callback.call(_player)
	_pending_callbacks.clear()
	player_registered.emit(player_node)


func run_when_player_ready(callback: Callable) -> void:
	if _player:
		callback.call(_player)
	else:
		_pending_callbacks.append(callback)


func clear() -> void:
	_player = null
	_pending_callbacks.clear()
