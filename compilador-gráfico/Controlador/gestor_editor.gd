extends Node
class_name GestorEditor

var programa_de_usuario : ASG_Programa = null
var escena_bloque = preload("res://Vista/Bloques/bloque_base.tscn")
var contenedor_flujo_ui : VBoxContainer = null
var fabrica_de_bloques : BloqueFactory = BloqueFactory.new()
var historial : UndoRedo = UndoRedo.new()

# Estado del editor para inserción
var id_padre_pendiente : int = -1
var puerto_pendiente : StringName = &"id_siguiente_ejecución"
var id_nodo_en_mutacion : int = -1
var estado_inyeccion_actual: Dictionary = {}

# Registro en memoria de las Definiciones (Los archivos .tres)
var registro_bloques : Dictionary[StringName, DefinicionBloque] = {}

func _ready() -> void:
	programa_de_usuario = ASG_Programa.new()
	_cargar_definiciones_temporales() # En el futuro, esto leerá de una carpeta

# Simula leer archivos .tres para el MVP
func _cargar_definiciones_temporales() -> void:
	# --- 1. DEFINICIÓN DEL EVENTO INICIAL ---
	var def_evento = DefinicionBloque.new()
	def_evento.nombre_visual = "Al Escanear Producto"
	def_evento.categoria = GabyEnums.CategoriaNodo.EVENTO
	def_evento.operacion_host = &"ON_PRODUCT_SCANNED"
	# Los eventos proveen variables al entorno en lugar de pedirlas
	var tipos_salidas_provistas : Dictionary[StringName,GabyEnums.TipoDato] ={
		&"producto_leido": GabyEnums.TipoDato.PRODUCTO
	}
	def_evento.tipos_salidas_provistas = tipos_salidas_provistas
	registro_bloques[&"ON_PRODUCT_SCANNED"] = def_evento
	
	# --- 2. DEFINICIÓN DE LA ACCIÓN ---
	var def_descuento = DefinicionBloque.new()
	def_descuento.nombre_visual = "Aplicar Descuento"
	def_descuento.categoria = GabyEnums.CategoriaNodo.ACCIÓN
	def_descuento.operacion_host = &"APPLY_DISCOUNT"
	var tipos_entradas_esperadas : Dictionary[StringName, GabyEnums.TipoDato] = {
		&"producto": GabyEnums.TipoDato.PRODUCTO,
		&"porcentaje": GabyEnums.TipoDato.INT
	}
	def_descuento.tipos_entradas_esperadas = tipos_entradas_esperadas
	registro_bloques[&"APPLY_DISCOUNT"] = def_descuento
	
	var def_if := DefinicionBloque.new()
	def_if.nombre_visual = "Condición (Si / Si No)"
	def_if.categoria = GabyEnums.CategoriaNodo.CONTROL
	def_if.operacion_host = &"IF_ELSE"
	# Exige un booleano para decidir qué camino tomar
	var tipos_entradas_esperadas2 : Dictionary[StringName, GabyEnums.TipoDato] ={
		&"condicion": GabyEnums.TipoDato.BOOLEAN
	}
	def_if.tipos_entradas_esperadas = tipos_entradas_esperadas2
	registro_bloques[&"IF_ELSE"] = def_if
	
	# --- 4. DEFINICIONES DE EXPRESIONES (MATEMÁTICA / LÓGICA) ---
	var def_menor_que := DefinicionBloque.new()
	def_menor_que.nombre_visual = "Menor Que (<)"
	def_menor_que.categoria = GabyEnums.CategoriaNodo.EXPRESION
	def_menor_que.operacion_host = &"LESS_THAN"
	var entradas : Dictionary[StringName, GabyEnums.TipoDato] = {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}
	def_menor_que.tipos_entradas_esperadas = entradas
	# Las expresiones SIEMPRE proveen una salida llamada "resultado"
	var salida : Dictionary[StringName, GabyEnums.TipoDato] = {
		&"resultado": GabyEnums.TipoDato.BOOLEAN
	}
	def_menor_que.tipos_salidas_provistas = salida
	registro_bloques[&"LESS_THAN"] = def_menor_que

# Encuentra el final de una rama para no sobreescribir bloques existentes
func _encontrar_cola_de_insercion(id_inicio: int, puerto_inicial: StringName) -> Dictionary:
	var nodo_actual = programa_de_usuario.obtener_nodo(id_inicio)
	var id_siguiente = nodo_actual.get(puerto_inicial)
	
	# Si la rama está vacía, insertamos directamente en el puerto del IF
	if id_siguiente == null or id_siguiente <= 0:
		return {"id": id_inicio, "puerto": puerto_inicial}
		
	# Si ya hay bloques, recorremos hasta encontrar el último
	var id_tail = id_siguiente
	while true:
		var nodo_tail = programa_de_usuario.obtener_nodo(id_tail)
		if "id_siguiente_ejecución" in nodo_tail and nodo_tail.id_siguiente_ejecución > 0:
			id_tail = nodo_tail.id_siguiente_ejecución
		else:
			break
			
	return {"id": id_tail, "puerto": &"id_siguiente_ejecución"}

# Prepara el estado y abre el menú
func iniciar_insercion_en_rama(id_padre: int, puerto: StringName) -> void:
	# Calculamos el final real de la rama
	var destino = _encontrar_cola_de_insercion(id_padre, puerto)
	id_padre_pendiente = destino["id"]
	puerto_pendiente = destino["puerto"]
	id_nodo_en_mutacion = -1
	
	var editor = get_parent()
	if editor.has_method("_abrir_menu_flotante_con_datos"):
		editor._abrir_menu_flotante_con_datos(obtener_definiciones_validas())

func agregar_bloque(id_operacion: StringName) -> void:
	if not registro_bloques.has(id_operacion): return
	var definicion : DefinicionBloque = registro_bloques[id_operacion]
	
	# Predecimos el ID
	var id_asignado = programa_de_usuario.ultimo_id + 1
	
	historial.create_action("Agregar Instrucción")
	
	# Usamos .bind() sobre las funciones destino
	historial.add_do_method(_ejecutar_agregar_bloque.bind(definicion, id_asignado, id_padre_pendiente, puerto_pendiente))
	historial.add_undo_method(_ejecutar_eliminacion_bloque.bind(id_asignado, id_padre_pendiente, puerto_pendiente))
	
	historial.commit_action()

func _ejecutar_agregar_bloque(definicion: DefinicionBloque, id_asignado: int, id_padre: int, puerto: StringName) -> void:
	var nuevo_nodo = fabrica_de_bloques.construir_bloque_logico(definicion.categoria)
	if not nuevo_nodo: return
	
	if nuevo_nodo is ASGAcción: nuevo_nodo.nombre_acción = definicion.operacion_host
	elif nuevo_nodo is ASGEvento: nuevo_nodo.nombre_evento = definicion.operacion_host
	elif nuevo_nodo is ASGControl: nuevo_nodo.nombre_control = definicion.operacion_host
	
	nuevo_nodo.tipos_entradas_esperadas = definicion.tipos_entradas_esperadas.duplicate()
	nuevo_nodo.tipos_salidas_provistas = definicion.tipos_salidas_provistas.duplicate()
	
	nuevo_nodo.id = id_asignado
	programa_de_usuario.nodos_grafos[id_asignado] = nuevo_nodo
	
	if id_asignado > programa_de_usuario.ultimo_id:
		programa_de_usuario.ultimo_id = id_asignado
		
	# Conexión usando el puerto dinámico
	if id_padre != -1:
		programa_de_usuario.conectar_flujo_ejecucion(id_padre, id_asignado, puerto)
		
	# El nuevo nodo pasa a ser el padre por defecto de las siguientes acciones
	id_padre_pendiente = id_asignado
	puerto_pendiente = &"id_siguiente_ejecución"
	
	renderizar_grafo_completo()

func _ejecutar_eliminacion_bloque(id_a_borrar: int, id_predecesor: int = -1, puerto_predecesor: StringName = &"id_siguiente_ejecución") -> void:
	programa_de_usuario.eliminar_nodo(id_a_borrar)
	
	# Restaurar el puntero de inserción al predecesor
	if id_padre_pendiente == id_a_borrar:
		id_padre_pendiente = id_predecesor 
		puerto_pendiente = puerto_predecesor
		
	renderizar_grafo_completo()

func _ejecutar_restauracion_bloque(nodo_respaldo: NodoBaseASG, id_predecesor: int, puerto_predecesor: StringName) -> void:
	# 1. Lo revivimos en el diccionario de datos
	programa_de_usuario.nodos_grafos[nodo_respaldo.id] = nodo_respaldo
	
	# 2. Reconectamos el cable de su padre original hacia él
	if id_predecesor != -1:
		programa_de_usuario.conectar_flujo_ejecucion(id_predecesor, nodo_respaldo.id, puerto_predecesor)
		
	# 3. Actualizamos el puntero para que el usuario pueda seguir escribiendo debajo de él
	id_padre_pendiente = nodo_respaldo.id
	puerto_pendiente = &"id_siguiente_ejecución"
		
	renderizar_grafo_completo()

# El filtro mágico con soporte de tipado forzado
func buscar_opciones_compatibles(id_destino: int, parametro: StringName, tipo_forzado: int = -1) -> Array:
	var opciones : Array = []
	var tipo_req = tipo_forzado
	
	if tipo_req == -1:
		var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
		if not nodo_destino: return opciones
		tipo_req = nodo_destino.tipos_entradas_esperadas.get(parametro, GabyEnums.TipoDato.ANY)
	
	# 1. Buscar en variables locales/globales
	for variable in programa_de_usuario.variables_locales:
		if variable.get("tipo") == tipo_req or tipo_req == GabyEnums.TipoDato.ANY:
			opciones.append({
				"texto_mostrar": "[Var] " + str(variable.get("nombre", "SinNombre")),
				"datos_conexion": {"fuente": "VARIABLE", "nombre": variable.get("nombre")}
			})
			
	# 2. Buscar salidas de nodos anteriores
	for id_candidato in programa_de_usuario.nodos_grafos.keys():
		if id_candidato == id_destino: continue
		var nodo_cand = programa_de_usuario.obtener_nodo(id_candidato)
		
		for nombre_salida in nodo_cand.tipos_salidas_provistas.keys():
			if nodo_cand.tipos_salidas_provistas[nombre_salida] == tipo_req or tipo_req == GabyEnums.TipoDato.ANY:
				opciones.append({
					"texto_mostrar": "[Salida " + str(id_candidato) + "] " + str(nombre_salida),
					"datos_conexion": {"fuente": "REFERENCIA_NODO", "id_origen": id_candidato, "puerto": nombre_salida}
				})
				
	
	#3. La Opción Especial para Crear Fórmulas
	opciones.append({
		"texto_mostrar": "[ ✨ Crear Fórmula... ]",
		"datos_conexion": {"fuente": "CREAR_EXPRESION", "tipo_esperado": tipo_req}
	})
	
	return opciones

func ejecutar_mutacion(nueva_operacion: StringName) -> void:
	var id_nodo = id_nodo_en_mutacion
	var nodo_viejo = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo_viejo: return
	
	# 1. Averiguamos cuál era la operación original para poder hacer el Undo
	var vieja_operacion : StringName = &""
	if nodo_viejo is ASGEvento: vieja_operacion = nodo_viejo.nombre_evento
	elif nodo_viejo is ASGAcción: vieja_operacion = nodo_viejo.nombre_acción
	
	# 2. Reseteamos el estado del editor (ya terminamos de usar el menú)
	id_nodo_en_mutacion = -1
	
	# 3. Creamos el Comando en el Historial
	historial.create_action("Cambiar Instrucción")
	
	# DO: Mutar a la nueva operación
	historial.add_do_method(_ejecutar_cambio_nodo.bind(id_nodo, nueva_operacion))
	
	# UNDO: Mutar de vuelta a la vieja operación
	historial.add_undo_method(_ejecutar_cambio_nodo.bind(id_nodo, vieja_operacion))
	
	historial.commit_action()

# La función ciega que altera el Modelo y dispara el redibujado
func _ejecutar_cambio_nodo(id_nodo: int, operacion_host: StringName) -> void:
	var definicion = registro_bloques.get(operacion_host)
	if not definicion: return
	
	# 1. Crear el nuevo Nodo Lógico
	var nuevo_nodo = fabrica_de_bloques.construir_bloque_logico(definicion.categoria)
	if nuevo_nodo is ASGAcción: nuevo_nodo.nombre_acción = operacion_host
	elif nuevo_nodo is ASGEvento: nuevo_nodo.nombre_evento = operacion_host
	nuevo_nodo.tipos_entradas_esperadas = definicion.tipos_entradas_esperadas.duplicate()
	nuevo_nodo.tipos_salidas_provistas = definicion.tipos_salidas_provistas.duplicate()
	
	# 2. El Modelo hace el reemplazo topológico y limpia referencias
	programa_de_usuario.mutar_nodo(id_nodo, nuevo_nodo)
	
	# 3. Magia del Immediate Mode: Que la pantalla se entere sola
	renderizar_grafo_completo()

func obtener_definiciones_validas() -> Array:
	var validas: Array = []
	
	# La regla de negocio: ¿Ya existe al menos un nodo (El Evento Inicial)?
	var tiene_evento_inicial: bool = not programa_de_usuario.nodos_grafos.is_empty()
	
	for key in registro_bloques.keys():
		var def: DefinicionBloque = registro_bloques[key]
		
		# REGLA DE ORO: Las Expresiones NUNCA van en la línea principal de ejecución.
		if def.categoria == GabyEnums.CategoriaNodo.EXPRESION:
			continue
		
		# Si está vacío, SOLO permitimos Eventos.
		if not tiene_evento_inicial and def.categoria == GabyEnums.CategoriaNodo.EVENTO:
			validas.append(def)
		# Si ya hay un evento, permitimos Acciones y Controles.
		elif tiene_evento_inicial and def.categoria != GabyEnums.CategoriaNodo.EVENTO:
			validas.append(def)
			
	return validas

func obtener_definiciones_para_mutacion(categoria_actual : GabyEnums.CategoriaNodo) -> Array:
	var validas : Array = []
	for key in registro_bloques.keys():
		var def : DefinicionBloque = registro_bloques[key]
		
		if def.categoria == categoria_actual:
			validas.append(def)
	
	return validas

func _on_bloque_solicita_eliminacion(id_a_borrar: int) -> void:
	var nodo_a_borrar = programa_de_usuario.obtener_nodo(id_a_borrar)
	if not nodo_a_borrar or nodo_a_borrar.categoria == GabyEnums.CategoriaNodo.EVENTO:
		return
		
	# 1. Hacer una "Fotografía" de la topología ANTES de borrar
	var id_predecesor : int = -1
	var puerto_predecesor : StringName = &""
	
	for id in programa_de_usuario.nodos_grafos.keys():
		var candidato = programa_de_usuario.obtener_nodo(id)
		if "id_siguiente_ejecución" in candidato and candidato.id_siguiente_ejecución == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_siguiente_ejecución"; break
		if "id_rama_verdadera" in candidato and candidato.id_rama_verdadera == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_rama_verdadera"; break
		if "id_rama_falsa" in candidato and candidato.id_rama_falsa == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_rama_falsa"; break
			
	# 2. Rescatamos el objeto en memoria (Sus parámetros y sus propios punteros siguen intactos)
	var nodo_respaldo = nodo_a_borrar
	
	# 3. Empaquetamos en el UndoRedo
	historial.create_action("Eliminar Instrucción")
	historial.add_do_method(_ejecutar_eliminacion_bloque.bind(id_a_borrar, id_predecesor, puerto_predecesor))
	historial.add_undo_method(_ejecutar_restauracion_bloque.bind(nodo_respaldo, id_predecesor, puerto_predecesor))
	historial.commit_action()

func _on_bloque_solicita_mutacion(id_nodo : int) -> void:
	id_nodo_en_mutacion = id_nodo
	var nodo_actual : NodoBaseASG = programa_de_usuario.obtener_nodo(id_nodo)
	
	var editor = get_parent() #El diablo hay que ver de arreglarlo despues TODO TODO TODO
	if editor.has_method("_abrir_menu_flotante_con_datos"):
		var definiciones = obtener_definiciones_para_mutacion(nodo_actual.categoria)
		editor._abrir_menu_flotante_con_datos(definiciones)

func _on_parametro_modificado(id_nodo : int, parametro : StringName, nuevo_valor : Variant) -> void:
	var nodo = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo: return
	
	# 1. Guardamos el estado anterior antes de sobrescribirlo
	var valor_previo = nodo.entradas_datos_conectadas.get(parametro, null)
	
	# 2. Creamos el Comando en el Historial
	historial.create_action("Modificar Parámetro")
	
	# 3. Aplicamos la nueva API usando .bind() para adjuntar los argumentos al Callable
	historial.add_do_method(_ejecutar_cambio_parametro.bind(id_nodo, parametro, nuevo_valor))
	historial.add_undo_method(_ejecutar_cambio_parametro.bind(id_nodo, parametro, valor_previo))
	
	# 4. Ejecutamos la acción
	historial.commit_action()

func _ejecutar_cambio_parametro(id_nodo: int, parametro: StringName, valor: Variant) -> void:
	var nodo : NodoBaseASG = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo: return
	
	if valor == null:
		nodo.entradas_datos_conectadas.erase(parametro)
	else:
		nodo.entradas_datos_conectadas[parametro] = valor
	
	
	renderizar_grafo_completo()

func renderizar_grafo_completo() -> void:
	if not contenedor_flujo_ui: return
	
	# 1. Purga visual completa
	for hijo in contenedor_flujo_ui.get_children():
		if hijo is BloqueBaseUI:
			hijo.queue_free()
			
	# 2. Encontrar el Evento Raíz (El punto de inicio)
	var id_raiz : int = -1
	for id in programa_de_usuario.nodos_grafos.keys():
		if programa_de_usuario.nodos_grafos[id].categoria == GabyEnums.CategoriaNodo.EVENTO:
			id_raiz = id
			break
			
	# 3. Lanzar la inyección recursiva
	if id_raiz != -1:
		_renderizar_secuencia(id_raiz, contenedor_flujo_ui)


# Función recursiva que dibuja una cadena de nodos en el contenedor que le pidas
func _renderizar_secuencia(id_inicio: int, contenedor_destino: Container) -> void:
	var id_actual : int = id_inicio
	
	while id_actual > 0:
		var nodo = programa_de_usuario.obtener_nodo(id_actual)
		if not nodo: break
		
		# Extraemos la operación base
		var operacion_host : StringName = &""
		if nodo is ASGEvento: operacion_host = nodo.nombre_evento
		elif nodo is ASGAcción: operacion_host = nodo.nombre_acción
		elif nodo is ASGControl: operacion_host = nodo.nombre_control
		
		var definicion = registro_bloques.get(operacion_host)
		if not definicion: break
		
		# 1. Instanciar UI en el contenedor correspondiente
		var bloque_ui : BloqueBaseUI = fabrica_de_bloques.construir_bloque_ui(definicion.categoria)
		contenedor_destino.add_child(bloque_ui)
		
		# Si estamos dibujando en la línea principal, respetamos el botón [+ Agregar] moviendo el bloque arriba
		if contenedor_destino == contenedor_flujo_ui:
			contenedor_destino.move_child(bloque_ui, contenedor_destino.get_child_count() - 2)
			
		var func_busqueda = Callable(self, "buscar_opciones_compatibles")
		bloque_ui.inicializar(id_actual, definicion.nombre_visual, definicion.tipos_entradas_esperadas, func_busqueda, nodo.entradas_datos_conectadas)
		
		# Reconectar señales en _renderizar_secuencia
		bloque_ui.solicitar_eliminacion.connect(_on_bloque_solicita_eliminacion)
		
		if bloque_ui.has_signal("solicitar_creacion_expresion"):
			if not bloque_ui.solicitar_creacion_expresion.is_connected(_on_solicitar_creacion_expresion):
				bloque_ui.solicitar_creacion_expresion.connect(_on_solicitar_creacion_expresion)
		
		bloque_ui.solicitar_mutacion.connect(_on_bloque_solicita_mutacion)
		if bloque_ui.has_signal("parametro_modificado"):
			bloque_ui.parametro_modificado.connect(_on_parametro_modificado)
		if bloque_ui is BloqueControlUI:
			bloque_ui.solicitar_insercion_rama.connect(iniciar_insercion_en_rama)
			
		# --- COMPORTAMIENTO RECURSIVO ---
		if nodo is ASGControl and bloque_ui is BloqueControlUI:
			if nodo.id_rama_verdadera > 0:
				_renderizar_secuencia(nodo.id_rama_verdadera, bloque_ui.rama_verdadera)
			if nodo.id_rama_falsa > 0:
				_renderizar_secuencia(nodo.id_rama_falsa, bloque_ui.rama_falsa)
				
			# Asegurar que el botón siempre quede al fondo
			bloque_ui.rama_verdadera.move_child(bloque_ui.boton_agregar_verdadero, -1)
			bloque_ui.rama_falsa.move_child(bloque_ui.boton_agregar_falso, -1)
		# 4. Avanzar al siguiente nodo en la línea de tiempo actual
		if "id_siguiente_ejecución" in nodo:
			id_actual = nodo.id_siguiente_ejecución
		else:
			id_actual = -1

func _on_solicitar_creacion_expresion(id_nodo: int, parametro: StringName, tipo_esperado: int) -> void:
	var editor = get_parent()
	if "modal_expresion" in editor and editor.modal_expresion:
		# Guardamos quién lo solicitó para dárselo a la inyección final
		estado_inyeccion_actual = {"id_destino": id_nodo, "parametro_destino": parametro}
		
		# Conectamos la señal del modal temporalmente (Asegúrate de desconectarla después si haces múltiples)
		if not editor.modal_expresion.formula_configurada.is_connected(_preparar_inyeccion_expresion):
			editor.modal_expresion.formula_configurada.connect(_preparar_inyeccion_expresion)
			
		var funcion_buscar = Callable(self, "buscar_opciones_compatibles")
		editor.modal_expresion.abrir_modal(id_nodo, parametro, tipo_esperado, registro_bloques, funcion_buscar)

func _preparar_inyeccion_expresion(operacion_host: StringName, parametros_ingresados: Dictionary) -> void:
	if estado_inyeccion_actual.is_empty(): return
	var id_destino = estado_inyeccion_actual["id_destino"]
	var parametro_destino = estado_inyeccion_actual["parametro_destino"]
	
	# Predecimos el ID de la fórmula en memoria
	var id_expresion_nueva = programa_de_usuario.ultimo_id + 1
	var definicion = registro_bloques[operacion_host]
	
	# Guardamos qué tenía el bloque original antes de la inyección por si usamos Ctrl+Z
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	var valor_previo = nodo_destino.entradas_datos_conectadas.get(parametro_destino, null)
	
	historial.create_action("Inyectar Fórmula")
	historial.add_do_method(_ejecutar_inyeccion_expresion.bind(id_destino, parametro_destino, id_expresion_nueva, definicion, parametros_ingresados))
	historial.add_undo_method(_ejecutar_deshacer_inyeccion.bind(id_destino, parametro_destino, id_expresion_nueva, valor_previo))
	historial.commit_action()
	
	estado_inyeccion_actual.clear() # Limpiamos el estado

func _ejecutar_inyeccion_expresion(id_destino: int, parametro_destino: StringName, id_expresion: int, definicion: DefinicionBloque, parametros_ingresados: Dictionary) -> void:
	# 1. Crear el nodo de Expresión
	var nodo_expr = ASGExpresión.new()
	nodo_expr.nombre_expresión = definicion.operacion_host
	nodo_expr.tipos_entradas_esperadas = definicion.tipos_entradas_esperadas.duplicate()
	nodo_expr.tipos_salidas_provistas = definicion.tipos_salidas_provistas.duplicate()
	
	# FIX APLICADO AQUÍ: Asignación al diccionario correcto tipado
	nodo_expr.entradas_datos_conectadas = parametros_ingresados.duplicate()
	
	# 2. Guardarlo en la memoria del programa
	nodo_expr.id = id_expresion
	programa_de_usuario.nodos_grafos[id_expresion] = nodo_expr
	
	if id_expresion > programa_de_usuario.ultimo_id:
		programa_de_usuario.ultimo_id = id_expresion
		
	# 3. Modificar el Nodo Destino (Acción/Control) para que su parámetro apunte al resultado de esta expresión
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	if nodo_destino:
		nodo_destino.entradas_datos_conectadas[parametro_destino] = {
			"fuente": "REFERENCIA_NODO",
			"id_origen": id_expresion,
			"puerto": "resultado"
		}
		
	renderizar_grafo_completo()

func _ejecutar_deshacer_inyeccion(id_destino: int, parametro_destino: StringName, id_expresion: int, valor_previo: Variant) -> void:
	# 1. Matamos la expresión de la memoria
	programa_de_usuario.nodos_grafos.erase(id_expresion)
	
	# 2. Restauramos el parámetro del nodo original
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	if nodo_destino:
		if valor_previo == null:
			nodo_destino.entradas_datos_conectadas.erase(parametro_destino)
		else:
			nodo_destino.entradas_datos_conectadas[parametro_destino] = valor_previo
			
	renderizar_grafo_completo()

func compilar() -> void:
	var json_generado = programa_de_usuario.generar_json_ir()
	print("--- JSON GENERADO PARA JAVA ---")
	print(json_generado)
