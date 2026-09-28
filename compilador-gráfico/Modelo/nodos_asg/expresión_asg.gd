extends NodoBaseASG
class_name ASGExpresión

@export var nombre_expresión : StringName = &""
@export var datos_entrada : Dictionary[StringName, Variant]

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EXPRESION

func to_dict() -> Dictionary[StringName, Variant]:
	var result : Dictionary[StringName, Variant] = {
		&"id" : id,
		&"tipo" : "EXPRESION",
		&"operación" : nombre_expresión,
		&"datos_entrada" : datos_entrada
	}
	return result
