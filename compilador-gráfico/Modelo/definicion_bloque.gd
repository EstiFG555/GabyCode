extends Resource
class_name DefinicionBloque

@export var nombre_visual : String = "Nuevo Bloque"
@export var categoria : GabyEnums.CategoriaNodo = GabyEnums.CategoriaNodo.ACCIÓN
@export var operacion_host : StringName = &""
@export var es_subrutina : bool = false

# Usamos int en el valor del diccionario para admitir tanto TipoDato como Objetos dinámicos
@export var tipos_entradas_esperadas : Dictionary[StringName, int] = {}
@export var tipos_salidas_provistas : Dictionary[StringName, int] = {}

# Si una salida es de tipo ARRAY, aquí guardamos el tipo de sus elementos (ej. PRODUCTO o INT)
@export var subtipos_array_salidas : Dictionary[StringName, int] = {}
