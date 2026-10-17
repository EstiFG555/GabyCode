extends Resource
class_name DefinicionBloque

@export var nombre_visual : String = "Nuevo Bloque"
@export var categoria : GabyEnums.CategoriaNodo = GabyEnums.CategoriaNodo.ACCIÓN
@export var operacion_host : StringName = &""

# Diccionarios tipados para las firmas
@export var tipos_entradas_esperadas : Dictionary[StringName, GabyEnums.TipoDato] = {}
@export var tipos_salidas_provistas : Dictionary[StringName, GabyEnums.TipoDato] = {}
