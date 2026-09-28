extends NodoBaseASG
class_name ASGControl

@export var nombre_control : StringName = &""
var id_rama_verdadera : int
var id_rama_falsa : int

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.CONTROL
