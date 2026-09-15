extends Element
class_name Cocoon

func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable  = true
	StageContext.register_cocoon(self)

func on_hit(atk_data: AtkData) -> bool:
	if atk_data.dmg < 1:
		ActionManager.record_new(self, atk_data.tick, "on_parryed")
		return false
	destroy_cocoon(atk_data.tick)
	return true

func destroy_cocoon(tick: int) -> void:
	hide_for_undo(tick)
	StageContext.notify_cocoon_destroyed(tick)
