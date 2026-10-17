extends NodoBaseASG
class_name ASGControl

@export var nombre_control : StringName = &""
var id_rama_verdadera : int = 0
var id_rama_falsa : int = 0
var id_siguiente_ejecución : int = 0 # El cable de salida principal

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.CONTROL

func to_dict() -> Dictionary[StringName, Variant]:
	var result : Dictionary[StringName, Variant] = {
		&"id" : id,
		&"tipo" : "CONTROL",
		&"acción" : nombre_control,
		# El equipo de Java recibirá siempre un array de 3 posiciones para el IF
		&"salidas_ejecucion" : [id_rama_verdadera, id_rama_falsa, id_siguiente_ejecución],
		&"entradas_datos" : entradas_datos_conectadas
	}
	
	return result
