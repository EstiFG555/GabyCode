extends Resource
class_name NodoBaseASG

var id : int = 0
@export var categoria : GabyEnums.CategoriaNodo
@export var tipos_entradas_esperadas : Dictionary[StringName, GabyEnums.TipoDato] = {}
@export var tipos_salidas_provistas : Dictionary[StringName, GabyEnums.TipoDato] = {}
var entradas_datos_conectadas : Dictionary = {} #Debería definir un diccionario más fuertemente tipado en el futuro

func to_dict() -> Dictionary[StringName, Variant]:
	push_error("to_dict() no implementado en la clsae ASG")
	return {}
