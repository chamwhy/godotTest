## Singleton.gd
extends Node # Godot의 기본 노드 상속
class_name Singleton

# static 변수로 자기 자신의 인스턴스를 저장할 공간을 만듭니다.
# 모든 Singleton 상속 클래스는 이 instance 변수를 통해 접근됩니다.
# 주의: GDScript는 generic 타입 지원이 약하므로, 자식 클래스에서 재정의 필요
static var instance: Singleton = null 

func _ready():
	# 1. 인스턴스가 이미 존재하는지 확인
	if Singleton.instance != null:
		# 이미 인스턴스가 존재하면 (복제 방지)
		push_error("%s: 이미 씬에 인스턴스가 존재합니다. 하나만 허용됩니다." % name)
		# 자신을 파괴
		queue_free() 
		return

	# 2. 현재 객체를 싱글톤 인스턴스로 설정
	Singleton.instance = self
	print("%s: Singleton 인스턴스 설정 완료." % name)
	
	# 3. 자식 클래스에서 초기화 로직을 실행하도록 가상 함수 호출
	_on_singleton_ready()

# 자식 클래스에서 오버라이드하여 사용할 초기화 함수 (Unity의 Awake와 유사)
func _on_singleton_ready():
	# 자식 클래스가 이 함수를 오버라이드하여 초기화 로직을 넣습니다.
	pass
