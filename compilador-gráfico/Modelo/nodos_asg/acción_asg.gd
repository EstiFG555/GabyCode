extends NodoBaseASG
class_name ASGAcción

@export var nombre_acción : StringName = &""
var id_siguiente_ejecución : int

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.ACCIÓN
