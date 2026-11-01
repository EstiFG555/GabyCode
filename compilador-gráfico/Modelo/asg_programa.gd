extends Resource
class_name ASG_Programa

var variables_locales : Array[Dictionary] = []
var nodos_grafos : Dictionary[int, NodoBaseASG] = {}
var ultimo_id : int = 0

func registrar_nodo(nodo : NodoBaseASG) -> int:
	ultimo_id += 1
	nodo.id = ultimo_id
	nodos_grafos[ultimo_id] = nodo
	return ultimo_id

func obtener_nodo(id_buscado : int) -> NodoBaseASG:
	return nodos_grafos.get(id_buscado, null)

func obtener_nodo_evento_raiz() -> ASGEvento:
	for id_n in nodos_grafos.keys():
		var n = nodos_grafos[id_n]
		if n is ASGEvento:
			return n
	return null

# --- CÁLCULO TOPOLÓGICO DE ANCESTROS ---
func obtener_ancestros_de_nodo(id_destino: int) -> Array[int]:
	var evento := obtener_nodo_evento_raiz()
	if not evento:
		return []
	var visitados_en_ruta : Array[int] = []
	var resultado : Array[int] = []
	_buscar_ruta_hacia_destino(evento.id, id_destino, visitados_en_ruta, resultado)
	return resultado

func _buscar_ruta_hacia_destino(id_actual: int, id_destino: int, ancestros_actuales: Array[int], resultado: Array[int]) -> bool:
	var copia_ancestros : Array[int] = ancestros_actuales.duplicate()
	
	while id_actual > 0:
		if id_actual == id_destino:
			resultado.assign(copia_ancestros)
			return true
			
		var nodo : NodoBaseASG = obtener_nodo(id_actual)
		if not nodo:
			break
			
		for con in nodo.entradas_datos_conectadas.values():
			if typeof(con) == TYPE_DICTIONARY and con.get("fuente") == "REFERENCIA_NODO":
				var id_orig : int = int(con.get("id_origen", -1))
				if _expresion_contiene_destino(id_orig, id_destino):
					resultado.assign(copia_ancestros)
					return true
					
		copia_ancestros.append(id_actual)
		
		if nodo is ASGControl:
			if nodo.id_rama_verdadera > 0:
				if _buscar_ruta_hacia_destino(nodo.id_rama_verdadera, id_destino, copia_ancestros, resultado):
					return true
			if nodo.id_rama_falsa > 0:
				if _buscar_ruta_hacia_destino(nodo.id_rama_falsa, id_destino, copia_ancestros, resultado):
					return true
					
		if "id_siguiente_ejecución" in nodo:
			id_actual = nodo.get(&"id_siguiente_ejecución")
		else:
			id_actual = -1
			
	return false

func _expresion_contiene_destino(id_expr: int, id_destino: int) -> bool:
	if id_expr == id_destino:
		return true
	var nodo := obtener_nodo(id_expr)
	if not nodo or nodo.categoria != GabyEnums.CategoriaNodo.EXPRESION:
		return false
	for con in nodo.entradas_datos_conectadas.values():
		if typeof(con) == TYPE_DICTIONARY and con.get("fuente") == "REFERENCIA_NODO":
			if _expresion_contiene_destino(int(con.get("id_origen", -1)), id_destino):
				return true
	return false

# --- GESTIÓN DE VARIABLES LOCALES ---
func existe_variable(nombre: String) -> bool:
	for v in variables_locales:
		if v.get("nombre") == nombre:
			return true
	return false

func obtener_tipo_variable(nombre: String) -> int:
	for v in variables_locales:
		if v.get("nombre") == nombre:
			return int(v.get("tipo", GabyEnums.TipoDato.ANY))
	return GabyEnums.TipoDato.ANY

func obtener_subtipo_variable(nombre: String) -> int:
	for v in variables_locales:
		if v.get("nombre") == nombre:
			return int(v.get("subtipo", GabyEnums.TipoDato.ANY))
	return GabyEnums.TipoDato.ANY

func agregar_variable(nombre: String, tipo: int, valor_inicial: Variant, subtipo: int = GabyEnums.TipoDato.ANY) -> void:
	if existe_variable(nombre):
		return
	variables_locales.append({
		"nombre": nombre,
		"tipo": tipo,
		"subtipo": subtipo,
		"valor_inicial": valor_inicial
	})

func eliminar_variable(nombre: String) -> void:
	for i in range(variables_locales.size() - 1, -1, -1):
		if variables_locales[i].get("nombre") == nombre:
			variables_locales.remove_at(i)
			
	for id_nodo in nodos_grafos.keys():
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		var claves_a_borrar : Array = []
		
		for parametro in nodo.entradas_datos_conectadas.keys():
			var conexion : Variant = nodo.entradas_datos_conectadas[parametro]
			if typeof(conexion) == TYPE_DICTIONARY and conexion.get("fuente") == "VARIABLE":
				if conexion.get("nombre") == nombre:
					claves_a_borrar.append(parametro)
					
		for clave in claves_a_borrar:
			nodo.entradas_datos_conectadas.erase(clave)
			if clave == &"variable_destino" and nodo.entradas_datos_conectadas.has(&"valor"):
				nodo.entradas_datos_conectadas.erase(&"valor")
				
	limpiar_expresiones_huerfanas()

# --- SISTEMA DE INSTANTÁNEAS PARA UNDO/REDO PROFUNDO ---
func crear_instantanea() -> Dictionary:
	var copia_nodos : Dictionary[int, NodoBaseASG] = {}
	for id_nodo in nodos_grafos.keys():
		var n : NodoBaseASG = nodos_grafos[id_nodo]
		var clon : NodoBaseASG = n.duplicate(true)
		clon.id = n.id
		clon.entradas_datos_conectadas = n.entradas_datos_conectadas.duplicate(true)
		clon.tipos_entradas_esperadas = n.tipos_entradas_esperadas.duplicate()
		clon.tipos_salidas_provistas = n.tipos_salidas_provistas.duplicate()
		clon.subtipos_array_salidas = n.subtipos_array_salidas.duplicate()
		if "id_siguiente_ejecución" in n:
			clon.set(&"id_siguiente_ejecución", n.get(&"id_siguiente_ejecución"))
		if n is ASGEvento and clon is ASGEvento:
			clon.orden_parametros_subrutina = n.orden_parametros_subrutina.duplicate()
			clon.tipo_retorno_subrutina = n.tipo_retorno_subrutina
			clon.subtipo_retorno_subrutina = n.subtipo_retorno_subrutina
		if n is ASGControl and clon is ASGControl:
			clon.id_rama_verdadera = n.id_rama_verdadera
			clon.id_rama_falsa = n.id_rama_falsa
		copia_nodos[id_nodo] = clon
		
	return {
		"ultimo_id": ultimo_id,
		"variables_locales": variables_locales.duplicate(true),
		"nodos_grafos": copia_nodos
	}

func restaurar_instantanea(instantanea: Dictionary) -> void:
	ultimo_id = instantanea["ultimo_id"]
	variables_locales.assign(instantanea["variables_locales"].duplicate(true))
	nodos_grafos.clear()
	var P : Dictionary = instantanea["nodos_grafos"]
	for id_nodo in P.keys():
		var n : NodoBaseASG = P[id_nodo]
		var clon : NodoBaseASG = n.duplicate(true)
		clon.id = n.id
		clon.entradas_datos_conectadas = n.entradas_datos_conectadas.duplicate(true)
		clon.tipos_entradas_esperadas = n.tipos_entradas_esperadas.duplicate()
		clon.tipos_salidas_provistas = n.tipos_salidas_provistas.duplicate()
		clon.subtipos_array_salidas = n.subtipos_array_salidas.duplicate()
		if "id_siguiente_ejecución" in n:
			clon.set(&"id_siguiente_ejecución", n.get(&"id_siguiente_ejecución"))
		if n is ASGEvento and clon is ASGEvento:
			clon.orden_parametros_subrutina = n.orden_parametros_subrutina.duplicate()
			clon.tipo_retorno_subrutina = n.tipo_retorno_subrutina
			clon.subtipo_retorno_subrutina = n.subtipo_retorno_subrutina
		if n is ASGControl and clon is ASGControl:
			clon.id_rama_verdadera = n.id_rama_verdadera
			clon.id_rama_falsa = n.id_rama_falsa
		nodos_grafos[id_nodo] = clon

# --- ELIMINACIÓN EN CASCADA Y RECOLECCIÓN DE BASURA ---
func eliminar_nodo(id_a_borrar: int) -> void:
	var nodo_a_borrar : NodoBaseASG = obtener_nodo(id_a_borrar)
	if not nodo_a_borrar:
		return
		
	var id_sucesor: int = 0
	if "id_siguiente_ejecución" in nodo_a_borrar:
		id_sucesor = nodo_a_borrar.id_siguiente_ejecución
		
	if nodo_a_borrar is ASGControl:
		if nodo_a_borrar.id_rama_verdadera > 0:
			_eliminar_secuencia_interna(nodo_a_borrar.id_rama_verdadera)
		if nodo_a_borrar.id_rama_falsa > 0:
			_eliminar_secuencia_interna(nodo_a_borrar.id_rama_falsa)
			
	for id_nodo in nodos_grafos.keys():
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		if "id_siguiente_ejecución" in nodo and nodo.id_siguiente_ejecución == id_a_borrar:
			nodo.id_siguiente_ejecución = id_sucesor
		if "id_rama_verdadera" in nodo and nodo.id_rama_verdadera == id_a_borrar:
			nodo.id_rama_verdadera = id_sucesor
		if "id_rama_falsa" in nodo and nodo.id_rama_falsa == id_a_borrar:
			nodo.id_rama_falsa = id_sucesor
			
	nodos_grafos.erase(id_a_borrar)
	limpiar_referencias_colgantes(id_a_borrar)
	limpiar_expresiones_huerfanas()

func _eliminar_secuencia_interna(id_inicio: int) -> void:
	var id_actual : int = id_inicio
	while id_actual > 0:
		var nodo : NodoBaseASG = obtener_nodo(id_actual)
		if not nodo:
			break
		var siguiente : int = 0
		if "id_siguiente_ejecución" in nodo:
			siguiente = nodo.id_siguiente_ejecución
			
		if nodo is ASGControl:
			if nodo.id_rama_verdadera > 0:
				_eliminar_secuencia_interna(nodo.id_rama_verdadera)
			if nodo.id_rama_falsa > 0:
				_eliminar_secuencia_interna(nodo.id_rama_falsa)
				
		nodos_grafos.erase(id_actual)
		limpiar_referencias_colgantes(id_actual)
		id_actual = siguiente

func limpiar_referencias_colgantes(id_objetivo : int) -> void:
	for id_nodo in nodos_grafos.keys():
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		var claves_a_borrar : Array = []
		
		for parametro in nodo.entradas_datos_conectadas.keys():
			var conexion : Variant = nodo.entradas_datos_conectadas[parametro]
			if typeof(conexion) == TYPE_DICTIONARY and conexion.get("fuente") == "REFERENCIA_NODO":
				if int(conexion.get("id_origen", -1)) == id_objetivo:
					claves_a_borrar.append(parametro)
		
		for clave in claves_a_borrar:
			nodo.entradas_datos_conectadas.erase(clave)

func limpiar_expresiones_huerfanas() -> void:
	var hubo_cambios : bool = true
	while hubo_cambios:
		hubo_cambios = false
		var ids_referenciados : Dictionary = {}
		
		for id_nodo in nodos_grafos.keys():
			var nodo : NodoBaseASG = nodos_grafos[id_nodo]
			for conexion in nodo.entradas_datos_conectadas.values():
				if typeof(conexion) == TYPE_DICTIONARY and conexion.get("fuente") == "REFERENCIA_NODO":
					ids_referenciados[int(conexion.get("id_origen", -1))] = true
					
		var expresiones_a_borrar : Array[int] = []
		for id_nodo in nodos_grafos.keys():
			var nodo : NodoBaseASG = nodos_grafos[id_nodo]
			if nodo.categoria == GabyEnums.CategoriaNodo.EXPRESION and not ids_referenciados.has(id_nodo):
				expresiones_a_borrar.append(id_nodo)
				
		for id_exp in expresiones_a_borrar:
			nodos_grafos.erase(id_exp)
			hubo_cambios = true

func mutar_nodo(id_a_mutar : int, nuevo_nodo : NodoBaseASG) -> void:
	var nodo_viejo : NodoBaseASG = obtener_nodo(id_a_mutar)
	if not nodo_viejo: return
	
	nuevo_nodo.id = id_a_mutar
	if "id_siguiente_ejecución" in nodo_viejo and "id_siguiente_ejecución" in nuevo_nodo:
		nuevo_nodo.id_siguiente_ejecución = nodo_viejo.id_siguiente_ejecución
		
	if nodo_viejo is ASGControl and nuevo_nodo is ASGControl:
		nuevo_nodo.id_rama_verdadera = nodo_viejo.id_rama_verdadera
		if nuevo_nodo.nombre_control == &"IF_ELSE":
			nuevo_nodo.id_rama_falsa = nodo_viejo.id_rama_falsa
		elif nodo_viejo.id_rama_falsa > 0:
			_eliminar_secuencia_interna(nodo_viejo.id_rama_falsa)
	
	nodos_grafos[id_a_mutar] = nuevo_nodo
	limpiar_referencias_colgantes(id_a_mutar)
	limpiar_expresiones_huerfanas()

func conectar_flujo_ejecucion(id_origen : int, id_destino : int, puerto : StringName = &"id_siguiente_ejecución") -> bool:
	var origen : NodoBaseASG = obtener_nodo(id_origen)
	if origen != null and puerto in origen:
		origen.set(puerto, id_destino)
		return true
	return false

func generar_json_ir() -> String:
	var exportacion : Dictionary[StringName, Variant] = {
		&"variables_locales" : variables_locales,
		&"nodos" : []
	}
	
	for id_nodo in nodos_grafos:
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		exportacion[&"nodos"].append(nodo.to_dict())
	
	return JSON.stringify(exportacion, "\t")

# --- DESERIALIZACIÓN: CARGAR PROGRAMA O SUBRUTINA DESDE JSON ---
func cargar_desde_json_string(json_str: String, registro_bloques: Dictionary, fabrica: BloqueFactory) -> bool:
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
		
	if parsed.has("grafo") and typeof(parsed["grafo"]) == TYPE_DICTIONARY:
		parsed = parsed["grafo"]
		
	variables_locales.clear()
	nodos_grafos.clear()
	ultimo_id = 0
	
	if parsed.has("variables_locales") and typeof(parsed["variables_locales"]) == TYPE_ARRAY:
		for v in parsed["variables_locales"]:
			if typeof(v) == TYPE_DICTIONARY:
				variables_locales.append({
					"nombre": str(v.get("nombre", "Var")),
					"tipo": int(v.get("tipo", GabyEnums.TipoDato.ANY)),
					"subtipo": int(v.get("subtipo", GabyEnums.TipoDato.ANY)),
					"valor_inicial": v.get("valor_inicial", 0)
				})
				
	if not parsed.has("nodos") or typeof(parsed["nodos"]) != TYPE_ARRAY:
		return false
		
	for n_dict in parsed["nodos"]:
		if typeof(n_dict) != TYPE_DICTIONARY: continue
		var id_n : int = int(n_dict.get("id", 0))
		if id_n <= 0: continue
		if id_n > ultimo_id: ultimo_id = id_n
		
		var tipo_str : String = str(n_dict.get("tipo", "ACCION")).to_upper()
		var op_str : String = str(n_dict.get("operacion", n_dict.get("acción", n_dict.get("operación", ""))))
		var op_name := StringName(op_str)
		var def : DefinicionBloque = registro_bloques.get(op_name, null)
		
		var nuevo_nodo : NodoBaseASG = null
		if tipo_str == "EVENTO":
			var ev := ASGEvento.new()
			ev.nombre_evento = op_name
			if n_dict.has("orden_parametros") and typeof(n_dict["orden_parametros"]) == TYPE_ARRAY:
				for p_nom in n_dict["orden_parametros"]:
					ev.orden_parametros_subrutina.append(str(p_nom))
			if n_dict.has("retorno_subrutina") and typeof(n_dict["retorno_subrutina"]) == TYPE_DICTIONARY:
				var ret_d : Dictionary = n_dict["retorno_subrutina"]
				if ret_d.has("tipo"):
					ev.tipo_retorno_subrutina = GabyEnums.obtener_id_tipo(str(ret_d["tipo"]))
					if ret_d.has("subtipo"):
						ev.subtipo_retorno_subrutina = GabyEnums.obtener_id_tipo(str(ret_d["subtipo"]))
			nuevo_nodo = ev
		elif tipo_str == "CONTROL":
			var ctrl := ASGControl.new()
			ctrl.nombre_control = op_name
			nuevo_nodo = ctrl
		elif tipo_str == "EXPRESION":
			var expr := ASGExpresión.new()
			expr.nombre_expresión = op_name
			nuevo_nodo = expr
		else:
			var acc := ASGAcción.new()
			acc.nombre_acción = op_name
			nuevo_nodo = acc
			
		nuevo_nodo.id = id_n
		if def:
			nuevo_nodo.tipos_entradas_esperadas = def.tipos_entradas_esperadas.duplicate()
			nuevo_nodo.tipos_salidas_provistas = def.tipos_salidas_provistas.duplicate()
			nuevo_nodo.subtipos_array_salidas = def.subtipos_array_salidas.duplicate()
			
		if n_dict.has("salidas_evento") and typeof(n_dict["salidas_evento"]) == TYPE_DICTIONARY:
			nuevo_nodo.tipos_salidas_provistas.clear()
			nuevo_nodo.subtipos_array_salidas.clear()
			var sal_ev : Dictionary = n_dict["salidas_evento"]
			for k in sal_ev.keys():
				var info = sal_ev[k]
				if typeof(info) == TYPE_DICTIONARY:
					nuevo_nodo.tipos_salidas_provistas[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("tipo", "ANY")))
					if info.has("subtipo"):
						nuevo_nodo.subtipos_array_salidas[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("subtipo", "ANY")))
						
		var salidas : Array = n_dict.get("salidas_ejecucion", [])
		if nuevo_nodo is ASGControl:
			if salidas.size() > 0: nuevo_nodo.id_rama_verdadera = int(salidas[0])
			if salidas.size() > 1: nuevo_nodo.id_rama_falsa = int(salidas[1])
			if salidas.size() > 2: nuevo_nodo.id_siguiente_ejecución = int(salidas[2])
		elif "id_siguiente_ejecución" in nuevo_nodo and salidas.size() > 0:
			nuevo_nodo.set(&"id_siguiente_ejecución", int(salidas[0]))
			
		var entradas_raw : Dictionary = n_dict.get("datos_entrada", n_dict.get("entradas_datos", {}))
		for k in entradas_raw.keys():
			var ed = entradas_raw[k]
			if typeof(ed) == TYPE_DICTIONARY:
				var copia_ed : Dictionary = ed.duplicate()
				if copia_ed.has("id_origen"):
					copia_ed["id_origen"] = int(copia_ed["id_origen"])
				nuevo_nodo.entradas_datos_conectadas[StringName(k)] = copia_ed
				
		nodos_grafos[id_n] = nuevo_nodo
		
	return true
