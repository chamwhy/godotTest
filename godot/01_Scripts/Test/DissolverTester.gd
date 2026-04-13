extends Node



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_5):
		print("디졸브 IN 시작 (1.5초)")
		await SceneTransition.fade_in()
		
	# 6번 키를 눌렀을 때 (Out: 사라지기)
	if Input.is_key_pressed(KEY_6):
		print("디졸브 OUT 시5작 (1.5초)")
		await SceneTransition.fade_out()
