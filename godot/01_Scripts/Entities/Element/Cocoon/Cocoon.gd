# Cocoon.gd
# 공격(dmg >= 1)을 받으면 파괴되는 오브젝트.
# 파괴 로직은 Wall의 파괴 가능 벽 1과 동일 패턴(hide_for_undo + vanish).
extends Element
class_name Cocoon

func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true    # 이동 막음. 필요시 data.get으로 조정
	hitable  = true
	StageContext.register_cocoon(self)
	# TODO: 스프라이트 세팅

func on_hit(atk_data: AtkData) -> bool:
	if atk_data.dmg < 1:
		ActionManager.record_new(self, atk_data.tick, "on_parryed")
		return false
	destroy_cocoon(atk_data.tick)
	return true

func destroy_cocoon(tick: int) -> void:
	hide_for_undo(tick)                          # 논리 즉시 exit + vanish/respawn 기록
	StageContext.notify_cocoon_destroyed(tick)   # 그 다음 전멸 판정 (내 in_map은 이미 false)
	# 소멸 연출은 base Element._anim_vanish 재사용(페이드+hide).
	# TODO: 파괴음/파티클이 필요하면 Wall처럼 _anim_vanish override
