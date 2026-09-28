extends NodoBaseASG
class_name ASGEvento

@export var nombre_evento : StringName = &""
var id_siguiente_ejecución : int

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EVENTO
