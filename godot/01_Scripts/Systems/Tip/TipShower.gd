extends Node


func _ready() -> void:
	# move tip
	GameManager.state_changed.connect(func(state: GameManager.GameState):
		if state == GameManager.GameState.PLAYING:
			TipContent.instance.show_tip("move")
	)
	
	
	
