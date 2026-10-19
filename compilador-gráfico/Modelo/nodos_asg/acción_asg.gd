extends NodoBaseASG
class_name ASGAcción

@export var nombre_acción : StringName = &""
var id_siguiente_ejecución : int = 0

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.ACCIÓN

func to_dict() -> Dictionary[StringName, Variant]:
	return {
		&"id" : id,
		&"tipo" : "ACCION",
		&"operacion" : nombre_acción,
		&"salidas_ejecucion" : [id_siguiente_ejecución] if id_siguiente_ejecución > 0 else [],
		&"datos_entrada" : entradas_datos_conectadas
	}
