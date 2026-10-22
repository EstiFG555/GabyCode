extends NodoBaseASG
class_name ASGEvento

@export var nombre_evento : StringName = &""
var id_siguiente_ejecución : int = 0
var orden_parametros_subrutina : Array[String] = []
var tipo_retorno_subrutina : int = -1 # -1 = Sin retorno (Void)
var subtipo_retorno_subrutina : int = GabyEnums.TipoDato.ANY

func _init() -> void:
	categoria = GabyEnums.CategoriaNodo.EVENTO

func to_dict() -> Dictionary[StringName, Variant]:
	var salidas_serializadas : Dictionary = {}
	for k in tipos_salidas_provistas.keys():
		var info : Dictionary = {"tipo": GabyEnums.obtener_nombre_codigo(tipos_salidas_provistas[k])}
		if subtipos_array_salidas.has(k):
			info["subtipo"] = GabyEnums.obtener_nombre_codigo(subtipos_array_salidas[k])
		salidas_serializadas[String(k)] = info
		
	var dict_retorno : Dictionary = {}
	if tipo_retorno_subrutina != -1:
		dict_retorno["tipo"] = GabyEnums.obtener_nombre_codigo(tipo_retorno_subrutina)
		if tipo_retorno_subrutina == GabyEnums.TipoDato.ARRAY:
			dict_retorno["subtipo"] = GabyEnums.obtener_nombre_codigo(subtipo_retorno_subrutina)
		
	return {
		&"id" : id,
		&"tipo" : "EVENTO",
		&"operacion" : nombre_evento,
		&"salidas_ejecucion" : [id_siguiente_ejecución] if id_siguiente_ejecución > 0 else [],
		&"datos_entrada" : entradas_datos_conectadas,
		&"salidas_evento" : salidas_serializadas,
		&"orden_parametros" : orden_parametros_subrutina,
		&"retorno_subrutina" : dict_retorno
	}
