# AutoLoad (UIManager.gd)
extends Node

# 씬에 배치된 Dissolver 객체를 여기에 등록해야 합니다.
var dissolver: Dissolver = null

func dissolve_in(duration: float) -> void:
	if dissolver:
		dissolver.dissolve_in(duration)
	else:
		push_warning("Dissolver 객체가 등록되지 않았습니다!")

func dissolve_out(duration: float) -> void:
	if dissolver:
		dissolver.dissolve_out(duration)
	else:
		push_warning("Dissolver 객체가 등록되지 않았습니다!")
