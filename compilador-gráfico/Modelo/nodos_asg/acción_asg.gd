extends NodoBaseASG
class_name ASGAcción

@export var nombre_acción : StringName = &""
var id_siguiente_ejecución : int

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.ACCIÓN

func to_dict() -> Dictionary[StringName, Variant]:
	var result : Dictionary[StringName, Variant] = {
		&"id" : id,
		&"tipo" : "ACCIÓN",
		&"acción" : nombre_acción,
		&"salidas_ejecucion" : [id_siguiente_ejecución] if id_siguiente_ejecución > 0 else [],
		&"entradas_datos" : entradas_datos_conectadas
	}
	
	return result
