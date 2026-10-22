extends Resource
class_name NodoBaseASG

var id : int = 0
@export var categoria : GabyEnums.CategoriaNodo
@export var tipos_entradas_esperadas : Dictionary[StringName, int] = {}
@export var tipos_salidas_provistas : Dictionary[StringName, int] = {}
@export var subtipos_array_salidas : Dictionary[StringName, int] = {}
var entradas_datos_conectadas : Dictionary = {}

func to_dict() -> Dictionary[StringName, Variant]:
	push_error("to_dict() no implementado en la clase ASG")
	return {}
