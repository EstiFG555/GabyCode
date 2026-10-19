extends NodoBaseASG
class_name ASGEvento

@export var nombre_evento : StringName = &""
var id_siguiente_ejecución : int = 0

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EVENTO

func to_dict() -> Dictionary[StringName, Variant]:
	return {
		&"id" : id,
		&"tipo" : "EVENTO",
		&"operacion" : nombre_evento,
		&"salidas_ejecucion" : [id_siguiente_ejecución] if id_siguiente_ejecución > 0 else [],
		&"datos_entrada" : entradas_datos_conectadas
	}
