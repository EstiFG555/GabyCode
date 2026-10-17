extends NodoBaseASG
class_name ASGExpresión

@export var nombre_expresión : StringName = &""

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EXPRESION

func to_dict() -> Dictionary[StringName, Variant]:
	var result : Dictionary[StringName, Variant] = {
		&"id" : id,
		&"tipo" : "EXPRESION",
		&"operación" : nombre_expresión,
		# Usamos la variable estandarizada del padre
		&"entradas_datos" : entradas_datos_conectadas 
	}
	return result
