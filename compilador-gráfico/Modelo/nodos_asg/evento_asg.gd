extends NodoBaseASG
class_name ASGEvento

@export var nombre_evento : StringName = &""
var id_siguiente_ejecución : int

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EVENTO

func to_dict() -> Dictionary[StringName, Variant]:
	var result : Dictionary[StringName, Variant] = {
		&"id" : id,
		&"tipo" : "EVENTO",
		&"acción" : nombre_evento,
		&"salidas_ejecucion" : [id_siguiente_ejecución] if id_siguiente_ejecución > 0 else [],
		&"entradas_datos" : entradas_datos_conectadas
	}
	
	return result
