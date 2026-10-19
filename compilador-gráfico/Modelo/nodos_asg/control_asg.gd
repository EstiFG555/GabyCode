extends NodoBaseASG
class_name ASGControl

@export var nombre_control : StringName = &""
var id_rama_verdadera : int = 0
var id_rama_falsa : int = 0
var id_siguiente_ejecución : int = 0

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.CONTROL

func to_dict() -> Dictionary[StringName, Variant]:
	return {
		&"id" : id,
		&"tipo" : "CONTROL",
		&"operacion" : nombre_control,
		# Convención de 3 puertos: [Rama_Verdadera / Cuerpo_Bucle, Rama_Falsa, Siguiente_Principal]
		&"salidas_ejecucion" : [id_rama_verdadera, id_rama_falsa, id_siguiente_ejecución],
		&"datos_entrada" : entradas_datos_conectadas
	}
