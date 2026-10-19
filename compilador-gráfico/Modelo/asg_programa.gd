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

# --- GESTIÓN DE VARIABLES LOCALES ---
func existe_variable(nombre: String) -> bool:
	for v in variables_locales:
		if v.get("nombre") == nombre:
			return true
	return false

func obtener_tipo_variable(nombre: String) -> int:
	for v in variables_locales:
		if v.get("nombre") == nombre:
			return v.get("tipo", GabyEnums.TipoDato.ANY)
	return GabyEnums.TipoDato.ANY

func agregar_variable(nombre: String, tipo: GabyEnums.TipoDato, valor_inicial: Variant) -> void:
	if existe_variable(nombre):
		return
	variables_locales.append({
		"nombre": nombre,
		"tipo": tipo,
		"valor_inicial": valor_inicial
	})

func eliminar_variable(nombre: String) -> void:
	for i in range(variables_locales.size() - 1, -1, -1):
		if variables_locales[i].get("nombre") == nombre:
			variables_locales.remove_at(i)
			
	# Limpiar referencias en todos los nodos que usaban esta variable
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
			# Si en un SET_VAR se borró la variable_destino, también limpiamos su valor asociado
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
		if "id_siguiente_ejecución" in n:
			clon.set(&"id_siguiente_ejecución", n.get(&"id_siguiente_ejecución"))
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
		if "id_siguiente_ejecución" in n:
			clon.set(&"id_siguiente_ejecución", n.get(&"id_siguiente_ejecución"))
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
				if conexion.get("id_origen") == id_objetivo:
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
					ids_referenciados[conexion.get("id_origen")] = true
					
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
