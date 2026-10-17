extends Resource
class_name ASG_Programa

var variables_locales : Array[Dictionary]
var nodos_grafos : Dictionary[int, NodoBaseASG]
var ultimo_id : int = 0

func registrar_nodo(nodo : NodoBaseASG) -> int:
	ultimo_id += 1
	nodo.id = ultimo_id
	nodos_grafos[ultimo_id] = nodo
	return ultimo_id

func obtener_nodo(id_buscado : int) -> NodoBaseASG:
	return nodos_grafos.get(id_buscado, null)

func eliminar_nodo(id_a_borrar: int) -> void:
	var nodo_a_borrar : NodoBaseASG = obtener_nodo(id_a_borrar)
	if not nodo_a_borrar:
		return
		
	# 1. Identificar el sucesor de ejecución del nodo que vamos a matar
	# (Asumimos que si tiene ramas, no deberíamos poder borrarlo limpiamente sin borrar
	# a sus hijos también. Para el MVP, asumiremos que un IF borrado puentea su cable principal)
	var id_sucesor: int = 0
	if "id_siguiente_ejecución" in nodo_a_borrar:
		id_sucesor = nodo_a_borrar.id_siguiente_ejecución
		
	# 2. Recorrer TODO el grafo para reparar y limpiar
	for id_nodo in nodos_grafos.keys():
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		
		# A) Puentear flujo de ejecución (EN TODOS LOS PUERTOS POSIBLES)
		if "id_siguiente_ejecución" in nodo and nodo.id_siguiente_ejecución == id_a_borrar:
			nodo.id_siguiente_ejecución = id_sucesor
		if "id_rama_verdadera" in nodo and nodo.id_rama_verdadera == id_a_borrar:
			nodo.id_rama_verdadera = id_sucesor
		if "id_rama_falsa" in nodo and nodo.id_rama_falsa == id_a_borrar:
			nodo.id_rama_falsa = id_sucesor
			
		# B) Limpiar Referencias Colgantes de Datos
		var claves_a_borrar = []
		for parametro in nodo.entradas_datos_conectadas.keys():
			var conexion : Variant = nodo.entradas_datos_conectadas[parametro]
			if typeof(conexion) == TYPE_DICTIONARY and conexion.get("fuente") == "REFERENCIA_NODO":
				if conexion.get("id_origen") == id_a_borrar:
					claves_a_borrar.append(parametro)
					
		for clave in claves_a_borrar:
			nodo.entradas_datos_conectadas.erase(clave)
			
	# 3. Eliminar el nodo de la base de datos
	nodos_grafos.erase(id_a_borrar)

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

func mutar_nodo(id_a_mutar : int, nuevo_nodo : NodoBaseASG) -> void:
	var nodo_viejo : NodoBaseASG = obtener_nodo(id_a_mutar)
	if not nodo_viejo: return
	
	nuevo_nodo.id = id_a_mutar
	if "id_siguiente_ejecución" in nodo_viejo and  "id_siguiente_ejecución" in nuevo_nodo:
		nuevo_nodo.id_siguiente_ejecución = nodo_viejo.id_siguiente_ejecución
	
	nodos_grafos[id_a_mutar] = nuevo_nodo
	
	limpiar_referencias_colgantes(id_a_mutar)

func conectar_flujo_ejecucion(id_origen : int, id_destino : int, puerto : StringName = &"id_siguiente_ejecución") -> bool:
	var origen : NodoBaseASG = obtener_nodo(id_origen)
	if origen != null and puerto in origen:
		# Usamos set() para asignar la variable de forma dinámica
		origen.set(puerto, id_destino)
		return true
	return false

# Devuelve un arreglo con los IDs ordenados lógicamente
func obtener_secuencia_logica() -> Array[int]:
	var secuencia : Array[int] = []
	var id_actual : int = -1
	
	# 1. Encontrar el Evento Raíz
	for id in nodos_grafos.keys():
		if nodos_grafos[id].categoria == GabyEnums.CategoriaNodo.EVENTO:
			id_actual = id
			break
			
	# 2. Recorrer el grafo siguiendo el cable de ejecución
	while id_actual != -1:
		secuencia.append(id_actual)
		var nodo : NodoBaseASG = nodos_grafos[id_actual]
		
		if "id_siguiente_ejecución" in nodo and nodo.id_siguiente_ejecución > 0:
			id_actual = nodo.id_siguiente_ejecución
		else:
			id_actual = -1 # Fin del programa
			
	return secuencia

func generar_json_ir() -> String:
	var exportacion : Dictionary[StringName,Variant] = {
		&"variables_locales" : variables_locales,
		&"nodos" : []
	}
	
	for id_nodo in nodos_grafos:
		var nodo : NodoBaseASG = nodos_grafos[id_nodo]
		exportacion[&"nodos"].append(nodo.to_dict())
	
	return JSON.stringify(exportacion, "\t")
