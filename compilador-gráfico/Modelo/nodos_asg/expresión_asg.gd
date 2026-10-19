extends NodoBaseASG
class_name ASGExpresión

@export var nombre_expresión : StringName = &""

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EXPRESION

func to_dict() -> Dictionary[StringName, Variant]:
	return {
		&"id" : id,
		&"tipo" : "EXPRESION",
		&"operacion" : nombre_expresión,
		&"datos_entrada" : entradas_datos_conectadas
	}
