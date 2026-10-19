extends Node
class_name GestorEditor

signal grafo_actualizado
signal compilacion_exitosa(ruta_archivo: String)

const CARPETA_DEFINICIONES : String = "user://definiciones/"

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

# Registro en memoria de las Definiciones
var registro_bloques : Dictionary[StringName, DefinicionBloque] = {}
var bloques_personalizados_ids : Array[StringName] = []

func _ready() -> void:
	programa_de_usuario = ASG_Programa.new()
	_cargar_definiciones_temporales()
	_cargar_definiciones_personalizadas_disco()

func _cargar_definiciones_temporales() -> void:
	# --- 1. EVENTOS ---
	_registrar_def("Al Escanear Producto", GabyEnums.CategoriaNodo.EVENTO, &"ON_PRODUCT_SCANNED", {}, {
		&"producto_leido": GabyEnums.TipoDato.PRODUCTO
	})
	
	# --- 2. ACCIONES BASE ---
	_registrar_def("Asignar Variable (SET)", GabyEnums.CategoriaNodo.ACCIÓN, &"SET_VAR", {
		&"variable_destino": GabyEnums.TipoDato.ANY,
		&"valor": GabyEnums.TipoDato.ANY
	}, {})
	
	_registrar_def("Aplicar Descuento", GabyEnums.CategoriaNodo.ACCIÓN, &"APPLY_DISCOUNT", {
		&"producto": GabyEnums.TipoDato.PRODUCTO,
		&"porcentaje": GabyEnums.TipoDato.INT
	}, {})
	
	_registrar_def("Mostrar Alerta", GabyEnums.CategoriaNodo.ACCIÓN, &"SHOW_ALERT", {
		&"mensaje": GabyEnums.TipoDato.STRING
	}, {})
	
	_registrar_def("Obtener Stock de Producto", GabyEnums.CategoriaNodo.ACCIÓN, &"GET_STOCK", {
		&"producto": GabyEnums.TipoDato.PRODUCTO
	}, {
		&"resultado": GabyEnums.TipoDato.INT
	})
	
	# --- 3. CONTROLES (IF_ELSE, WHILE, FOREACH) ---
	_registrar_def("Condición (Si / Si No)", GabyEnums.CategoriaNodo.CONTROL, &"IF_ELSE", {
		&"condicion": GabyEnums.TipoDato.BOOLEAN
	}, {})
	
	_registrar_def("Bucle (Mientras / While)", GabyEnums.CategoriaNodo.CONTROL, &"WHILE", {
		&"condicion": GabyEnums.TipoDato.BOOLEAN
	}, {})
	
	_registrar_def("Bucle Para Cada (ForEach)", GabyEnums.CategoriaNodo.CONTROL, &"FOREACH", {
		&"coleccion": GabyEnums.TipoDato.ARRAY,
		&"variable_iteradora": GabyEnums.TipoDato.ANY
	}, {
		&"elemento_actual": GabyEnums.TipoDato.ANY
	})
	
	# --- 4. EXPRESIONES LÓGICAS Y MATEMÁTICAS ---
	_registrar_def("Menor Que (<)", GabyEnums.CategoriaNodo.EXPRESION, &"LESS_THAN", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.BOOLEAN})
	
	_registrar_def("Mayor Que (>)", GabyEnums.CategoriaNodo.EXPRESION, &"GREATER_THAN", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.BOOLEAN})
	
	_registrar_def("Igual A (==)", GabyEnums.CategoriaNodo.EXPRESION, &"EQUAL", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.BOOLEAN})
	
	_registrar_def("Sumar (+)", GabyEnums.CategoriaNodo.EXPRESION, &"ADD", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.INT})
	
	_registrar_def("Restar (-)", GabyEnums.CategoriaNodo.EXPRESION, &"SUB", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.INT})
	
	_registrar_def("Multiplicar (*)", GabyEnums.CategoriaNodo.EXPRESION, &"MUL", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.INT})
	
	_registrar_def("Dividir (/)", GabyEnums.CategoriaNodo.EXPRESION, &"DIV", {
		&"valor_a": GabyEnums.TipoDato.INT,
		&"valor_b": GabyEnums.TipoDato.INT
	}, {&"resultado": GabyEnums.TipoDato.INT})

func _registrar_def(nombre: String, cat: GabyEnums.CategoriaNodo, op: StringName, entradas: Dictionary, salidas: Dictionary) -> DefinicionBloque:
	var def := DefinicionBloque.new()
	def.nombre_visual = nombre
	def.categoria = cat
	def.operacion_host = op
	var ent_tipadas : Dictionary[StringName, GabyEnums.TipoDato] = {}
	for k in entradas.keys(): ent_tipadas[StringName(k)] = entradas[k]
	var sal_tipadas : Dictionary[StringName, GabyEnums.TipoDato] = {}
	for k in salidas.keys(): sal_tipadas[StringName(k)] = salidas[k]
	def.tipos_entradas_esperadas = ent_tipadas
	def.tipos_salidas_provistas = sal_tipadas
	registro_bloques[op] = def
	return def

# --- CREACIÓN Y PERSISTENCIA DE BLOQUES PERSONALIZADOS ---
func crear_bloque_accion_personalizado(nombre_visual: String, operacion_host_raw: String, entradas: Dictionary, salidas: Dictionary) -> bool:
	var op_limpia : String = operacion_host_raw.strip_edges().to_upper().replace(" ", "_")
	if nombre_visual.strip_edges() == "" or op_limpia == "":
		return false
	var op_name := StringName(op_limpia)
	if registro_bloques.has(op_name):
		push_warning("Ya existe un bloque con la operación: " + op_limpia)
		return false
		
	var nueva_def : DefinicionBloque = _registrar_def(nombre_visual.strip_edges(), GabyEnums.CategoriaNodo.ACCIÓN, op_name, entradas, salidas)
	bloques_personalizados_ids.append(op_name)
	
	if not DirAccess.dir_exists_absolute(CARPETA_DEFINICIONES):
		DirAccess.make_dir_recursive_absolute(CARPETA_DEFINICIONES)
	var ruta_archivo : String = CARPETA_DEFINICIONES + op_limpia.to_lower() + ".tres"
	ResourceSaver.save(nueva_def, ruta_archivo)
	
	grafo_actualizado.emit()
	return true

func eliminar_bloque_personalizado(op_name: StringName) -> void:
	if not bloques_personalizados_ids.has(op_name):
		return
	bloques_personalizados_ids.erase(op_name)
	registro_bloques.erase(op_name)
	
	var ruta_archivo : String = CARPETA_DEFINICIONES + String(op_name).to_lower() + ".tres"
	if FileAccess.file_exists(ruta_archivo):
		DirAccess.remove_absolute(ruta_archivo)
		
	renderizar_grafo_completo()

func _cargar_definiciones_personalizadas_disco() -> void:
	if not DirAccess.dir_exists_absolute(CARPETA_DEFINICIONES):
		return
	var dir := DirAccess.open(CARPETA_DEFINICIONES)
	if not dir: return
	
	dir.list_dir_begin()
	var archivo : String = dir.get_next()
	while archivo != "":
		if not dir.current_is_dir() and archivo.ends_with(".tres"):
			var recurso = ResourceLoader.load(CARPETA_DEFINICIONES + archivo)
			if recurso is DefinicionBloque and not registro_bloques.has(recurso.operacion_host):
				registro_bloques[recurso.operacion_host] = recurso
				bloques_personalizados_ids.append(recurso.operacion_host)
		archivo = dir.get_next()
	dir.list_dir_end()

# --- COMANDOS DE VARIABLES LOCALES (CON UNDO/REDO) ---
func crear_variable_local(nombre: String, tipo: GabyEnums.TipoDato, valor_inicial: Variant) -> bool:
	var nombre_limpio = nombre.strip_edges().replace(" ", "_")
	if nombre_limpio == "" or programa_de_usuario.existe_variable(nombre_limpio):
		return false
		
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Crear Variable " + nombre_limpio)
	historial.add_do_method(_ejecutar_crear_variable.bind(nombre_limpio, tipo, valor_inicial))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()
	return true

func _ejecutar_crear_variable(nombre: String, tipo: GabyEnums.TipoDato, valor_inicial: Variant) -> void:
	programa_de_usuario.agregar_variable(nombre, tipo, valor_inicial)
	renderizar_grafo_completo()

func eliminar_variable_local(nombre: String) -> void:
	if not programa_de_usuario.existe_variable(nombre):
		return
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Eliminar Variable " + nombre)
	historial.add_do_method(_ejecutar_eliminar_variable.bind(nombre))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _ejecutar_eliminar_variable(nombre: String) -> void:
	programa_de_usuario.eliminar_variable(nombre)
	renderizar_grafo_completo()

# --- LÓGICA DE INSERCIÓN Y NODOS ---
func _encontrar_cola_de_insercion(id_inicio: int, puerto_inicial: StringName) -> Dictionary:
	var nodo_actual = programa_de_usuario.obtener_nodo(id_inicio)
	var id_siguiente = nodo_actual.get(puerto_inicial)
	
	if id_siguiente == null or id_siguiente <= 0:
		return {"id": id_inicio, "puerto": puerto_inicial}
		
	var id_tail = id_siguiente
	while true:
		var nodo_tail = programa_de_usuario.obtener_nodo(id_tail)
		if "id_siguiente_ejecución" in nodo_tail and nodo_tail.id_siguiente_ejecución > 0:
			id_tail = nodo_tail.id_siguiente_ejecución
		else:
			break
			
	return {"id": id_tail, "puerto": &"id_siguiente_ejecución"}

func iniciar_insercion_en_rama(id_padre: int, puerto: StringName) -> void:
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
	
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	var id_asignado = programa_de_usuario.ultimo_id + 1
	
	historial.create_action("Agregar Instrucción")
	historial.add_do_method(_ejecutar_agregar_bloque.bind(definicion, id_asignado, id_padre_pendiente, puerto_pendiente))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
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
		
	if id_padre != -1:
		programa_de_usuario.conectar_flujo_ejecucion(id_padre, id_asignado, puerto)
		
	id_padre_pendiente = id_asignado
	puerto_pendiente = &"id_siguiente_ejecución"
	
	renderizar_grafo_completo()

func _ejecutar_restaurar_instantanea(instantanea: Dictionary, padre_restaurado: int, puerto_restaurado: StringName) -> void:
	programa_de_usuario.restaurar_instantanea(instantanea)
	id_padre_pendiente = padre_restaurado
	puerto_pendiente = puerto_restaurado
	renderizar_grafo_completo()

func _ejecutar_eliminacion_bloque(id_a_borrar: int, id_predecesor: int = -1, puerto_predecesor: StringName = &"id_siguiente_ejecución") -> void:
	programa_de_usuario.eliminar_nodo(id_a_borrar)
	
	if id_padre_pendiente == id_a_borrar or not programa_de_usuario.nodos_grafos.has(id_padre_pendiente):
		id_padre_pendiente = id_predecesor 
		puerto_pendiente = puerto_predecesor
		
	renderizar_grafo_completo()

func buscar_opciones_compatibles(id_destino: int, parametro: StringName, tipo_forzado: int = -1) -> Array:
	var opciones : Array = []
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	
	if parametro == &"variable_destino" or parametro == &"variable_iteradora":
		for variable in programa_de_usuario.variables_locales:
			opciones.append({
				"texto_mostrar": "[Var] " + str(variable.get("nombre", "SinNombre")),
				"datos_conexion": {"fuente": "VARIABLE", "nombre": variable.get("nombre")}
			})
		return opciones
	
	var tipo_req = tipo_forzado
	if tipo_req == -1:
		if not nodo_destino: return opciones
		tipo_req = nodo_destino.tipos_entradas_esperadas.get(parametro, GabyEnums.TipoDato.ANY)
		
		if nodo_destino is ASGAcción and nodo_destino.nombre_acción == &"SET_VAR" and parametro == &"valor":
			if nodo_destino.entradas_datos_conectadas.has(&"variable_destino"):
				var con_var = nodo_destino.entradas_datos_conectadas[&"variable_destino"]
				if typeof(con_var) == TYPE_DICTIONARY and con_var.get("fuente") == "VARIABLE":
					tipo_req = programa_de_usuario.obtener_tipo_variable(str(con_var.get("nombre", "")))
	
	for variable in programa_de_usuario.variables_locales:
		if variable.get("tipo") == tipo_req or tipo_req == GabyEnums.TipoDato.ANY:
			opciones.append({
				"texto_mostrar": "[Var] " + str(variable.get("nombre", "SinNombre")),
				"datos_conexion": {"fuente": "VARIABLE", "nombre": variable.get("nombre")}
			})
			
	for id_candidato in programa_de_usuario.nodos_grafos.keys():
		if id_candidato == id_destino: continue
		var nodo_cand = programa_de_usuario.obtener_nodo(id_candidato)
		if nodo_cand.categoria == GabyEnums.CategoriaNodo.EXPRESION: continue
		
		for nombre_salida in nodo_cand.tipos_salidas_provistas.keys():
			if nodo_cand.tipos_salidas_provistas[nombre_salida] == tipo_req or tipo_req == GabyEnums.TipoDato.ANY:
				opciones.append({
					"texto_mostrar": "[Salida " + str(id_candidato) + "] " + str(nombre_salida),
					"datos_conexion": {"fuente": "REFERENCIA_NODO", "id_origen": id_candidato, "puerto": nombre_salida}
				})
				
	if nodo_destino and nodo_destino.entradas_datos_conectadas.has(parametro):
		var con = nodo_destino.entradas_datos_conectadas[parametro]
		if typeof(con) == TYPE_DICTIONARY and con.get("fuente") == "REFERENCIA_NODO":
			var id_orig = con.get("id_origen", -1)
			var nodo_orig = programa_de_usuario.obtener_nodo(id_orig)
			if nodo_orig and nodo_orig.categoria == GabyEnums.CategoriaNodo.EXPRESION:
				opciones.append({
					"texto_mostrar": "[Fórmula #" + str(id_orig) + "] " + str(nodo_orig.nombre_expresión),
					"datos_conexion": {"fuente": "REFERENCIA_NODO", "id_origen": id_orig, "puerto": "resultado"}
				})
	
	if tipo_req in [GabyEnums.TipoDato.INT, GabyEnums.TipoDato.FLOAT, GabyEnums.TipoDato.BOOLEAN, GabyEnums.TipoDato.ANY]:
		opciones.append({
			"texto_mostrar": "[ ✨ Crear Fórmula... ]",
			"datos_conexion": {"fuente": "CREAR_EXPRESION", "tipo_esperado": tipo_req}
		})
	
	return opciones

func ejecutar_mutacion(nueva_operacion: StringName) -> void:
	var id_nodo = id_nodo_en_mutacion
	var nodo_viejo = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo_viejo: return
	
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	id_nodo_en_mutacion = -1
	
	historial.create_action("Cambiar Instrucción")
	historial.add_do_method(_ejecutar_cambio_nodo.bind(id_nodo, nueva_operacion))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _ejecutar_cambio_nodo(id_nodo: int, operacion_host: StringName) -> void:
	var definicion = registro_bloques.get(operacion_host)
	if not definicion: return
	
	var nuevo_nodo = fabrica_de_bloques.construir_bloque_logico(definicion.categoria)
	if nuevo_nodo is ASGAcción: nuevo_nodo.nombre_acción = operacion_host
	elif nuevo_nodo is ASGEvento: nuevo_nodo.nombre_evento = operacion_host
	elif nuevo_nodo is ASGControl: nuevo_nodo.nombre_control = operacion_host
	
	nuevo_nodo.tipos_entradas_esperadas = definicion.tipos_entradas_esperadas.duplicate()
	nuevo_nodo.tipos_salidas_provistas = definicion.tipos_salidas_provistas.duplicate()
	
	programa_de_usuario.mutar_nodo(id_nodo, nuevo_nodo)
	renderizar_grafo_completo()

func obtener_definiciones_validas() -> Array:
	var validas: Array = []
	var tiene_evento_inicial: bool = not programa_de_usuario.nodos_grafos.is_empty()
	
	for key in registro_bloques.keys():
		var def: DefinicionBloque = registro_bloques[key]
		if def.categoria == GabyEnums.CategoriaNodo.EXPRESION:
			continue
		if not tiene_evento_inicial and def.categoria == GabyEnums.CategoriaNodo.EVENTO:
			validas.append(def)
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
		
	var id_predecesor : int = -1
	var puerto_predecesor : StringName = &"id_siguiente_ejecución"
	
	for id in programa_de_usuario.nodos_grafos.keys():
		var candidato = programa_de_usuario.obtener_nodo(id)
		if "id_siguiente_ejecución" in candidato and candidato.id_siguiente_ejecución == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_siguiente_ejecución"; break
		if "id_rama_verdadera" in candidato and candidato.id_rama_verdadera == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_rama_verdadera"; break
		if "id_rama_falsa" in candidato and candidato.id_rama_falsa == id_a_borrar:
			id_predecesor = id; puerto_predecesor = &"id_rama_falsa"; break
			
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	
	historial.create_action("Eliminar Instrucción")
	historial.add_do_method(_ejecutar_eliminacion_bloque.bind(id_a_borrar, id_predecesor, puerto_predecesor))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _on_bloque_solicita_mutacion(id_nodo : int) -> void:
	id_nodo_en_mutacion = id_nodo
	var nodo_actual : NodoBaseASG = programa_de_usuario.obtener_nodo(id_nodo)
	
	var editor = get_parent()
	if editor.has_method("_abrir_menu_flotante_con_datos"):
		var definiciones = obtener_definiciones_para_mutacion(nodo_actual.categoria)
		editor._abrir_menu_flotante_con_datos(definiciones)

func _on_parametro_modificado(id_nodo : int, parametro : StringName, nuevo_valor : Variant) -> void:
	var nodo = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo: return
	
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	
	historial.create_action("Modificar Parámetro")
	historial.add_do_method(_ejecutar_cambio_parametro.bind(id_nodo, parametro, nuevo_valor))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _ejecutar_cambio_parametro(id_nodo: int, parametro: StringName, valor: Variant) -> void:
	var nodo : NodoBaseASG = programa_de_usuario.obtener_nodo(id_nodo)
	if not nodo: return
	
	if valor == null:
		nodo.entradas_datos_conectadas.erase(parametro)
	else:
		nodo.entradas_datos_conectadas[parametro] = valor
		
	if nodo is ASGAcción and nodo.nombre_acción == &"SET_VAR" and parametro == &"variable_destino":
		nodo.entradas_datos_conectadas.erase(&"valor")
		
	programa_de_usuario.limpiar_expresiones_huerfanas()
	renderizar_grafo_completo()

# --- RENDERIZADO DECLARATIVO CON FLECHAS CONECTORAS ---
func _crear_conector_flecha() -> Control:
	var lbl := Label.new()
	lbl.text = "│\n▼"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.set_meta("es_conector_flujo", true)
	return lbl

func renderizar_grafo_completo() -> void:
	if not contenedor_flujo_ui: return
	
	for hijo in contenedor_flujo_ui.get_children():
		if hijo is BloqueBaseUI or hijo.has_meta("es_conector_flujo"):
			hijo.queue_free()
			
	var id_raiz : int = -1
	for id in programa_de_usuario.nodos_grafos.keys():
		if programa_de_usuario.nodos_grafos[id].categoria == GabyEnums.CategoriaNodo.EVENTO:
			id_raiz = id
			break
			
	if id_raiz != -1:
		_renderizar_secuencia(id_raiz, contenedor_flujo_ui)
		
	# Asegurar que el botón global [+ Agregar Instrucción] quede siempre al final
	for hijo in contenedor_flujo_ui.get_children():
		if hijo is Button:
			contenedor_flujo_ui.move_child(hijo, -1)
			break
			
	grafo_actualizado.emit()

func _renderizar_secuencia(id_inicio: int, contenedor_destino: Container) -> void:
	var id_actual : int = id_inicio
	var es_primero_en_secuencia : bool = true
	
	while id_actual > 0:
		var nodo = programa_de_usuario.obtener_nodo(id_actual)
		if not nodo: break
		
		var operacion_host : StringName = &""
		if nodo is ASGEvento: operacion_host = nodo.nombre_evento
		elif nodo is ASGAcción: operacion_host = nodo.nombre_acción
		elif nodo is ASGControl: operacion_host = nodo.nombre_control
		
		var definicion = registro_bloques.get(operacion_host)
		if not definicion: break
		
		# Insertar flecha conectora antes de cada bloque sucesivo (o al entrar a una sub-rama)
		if not es_primero_en_secuencia or contenedor_destino != contenedor_flujo_ui:
			var flecha := _crear_conector_flecha()
			contenedor_destino.add_child(flecha)
		es_primero_en_secuencia = false
		
		var bloque_ui : BloqueBaseUI = fabrica_de_bloques.construir_bloque_ui(definicion.categoria)
		contenedor_destino.add_child(bloque_ui)
			
		var func_busqueda = Callable(self, "buscar_opciones_compatibles")
		bloque_ui.inicializar(id_actual, definicion.nombre_visual, definicion.tipos_entradas_esperadas, func_busqueda, nodo.entradas_datos_conectadas)
		
		bloque_ui.solicitar_eliminacion.connect(_on_bloque_solicita_eliminacion)
		
		if bloque_ui.has_signal("solicitar_creacion_expresion"):
			if not bloque_ui.solicitar_creacion_expresion.is_connected(_on_solicitar_creacion_expresion):
				bloque_ui.solicitar_creacion_expresion.connect(_on_solicitar_creacion_expresion)
		
		bloque_ui.solicitar_mutacion.connect(_on_bloque_solicita_mutacion)
		if bloque_ui.has_signal("parametro_modificado"):
			bloque_ui.parametro_modificado.connect(_on_parametro_modificado)
			
		if bloque_ui is BloqueControlUI:
			bloque_ui.configurar_modo_control(operacion_host)
			bloque_ui.solicitar_insercion_rama.connect(iniciar_insercion_en_rama)
			
		if nodo is ASGControl and bloque_ui is BloqueControlUI:
			if nodo.id_rama_verdadera > 0:
				_renderizar_secuencia(nodo.id_rama_verdadera, bloque_ui.rama_verdadera)
			if nodo.id_rama_falsa > 0 and operacion_host == &"IF_ELSE":
				_renderizar_secuencia(nodo.id_rama_falsa, bloque_ui.rama_falsa)
				
			bloque_ui.rama_verdadera.move_child(bloque_ui.boton_agregar_verdadero, -1)
			bloque_ui.rama_falsa.move_child(bloque_ui.boton_agregar_falso, -1)
			
		if "id_siguiente_ejecución" in nodo:
			id_actual = nodo.id_siguiente_ejecución
		else:
			id_actual = -1
			
	# Conector final hacia el botón de agregar en la línea principal
	if contenedor_destino == contenedor_flujo_ui and not es_primero_en_secuencia:
		contenedor_destino.add_child(_crear_conector_flecha())

func _on_solicitar_creacion_expresion(id_nodo: int, parametro: StringName, tipo_esperado: int) -> void:
	var editor = get_parent()
	if "modal_expresion" in editor and editor.modal_expresion:
		estado_inyeccion_actual = {"id_destino": id_nodo, "parametro_destino": parametro}
		
		if not editor.modal_expresion.formula_configurada.is_connected(_preparar_inyeccion_expresion):
			editor.modal_expresion.formula_configurada.connect(_preparar_inyeccion_expresion)
			
		var funcion_buscar = Callable(self, "buscar_opciones_compatibles")
		editor.modal_expresion.abrir_modal(id_nodo, parametro, tipo_esperado, registro_bloques, funcion_buscar)

func _preparar_inyeccion_expresion(operacion_host: StringName, parametros_ingresados: Dictionary) -> void:
	if estado_inyeccion_actual.is_empty(): return
	var id_destino = estado_inyeccion_actual["id_destino"]
	var parametro_destino = estado_inyeccion_actual["parametro_destino"]
	
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	var id_expresion_nueva = programa_de_usuario.ultimo_id + 1
	var definicion = registro_bloques[operacion_host]
	
	historial.create_action("Inyectar Fórmula")
	historial.add_do_method(_ejecutar_inyeccion_expresion.bind(id_destino, parametro_destino, id_expresion_nueva, definicion, parametros_ingresados))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()
	
	estado_inyeccion_actual.clear()

func _ejecutar_inyeccion_expresion(id_destino: int, parametro_destino: StringName, id_expresion: int, definicion: DefinicionBloque, parametros_ingresados: Dictionary) -> void:
	var nodo_expr = ASGExpresión.new()
	nodo_expr.nombre_expresión = definicion.operacion_host
	nodo_expr.tipos_entradas_esperadas = definicion.tipos_entradas_esperadas.duplicate()
	nodo_expr.tipos_salidas_provistas = definicion.tipos_salidas_provistas.duplicate()
	nodo_expr.entradas_datos_conectadas = parametros_ingresados.duplicate()
	
	nodo_expr.id = id_expresion
	programa_de_usuario.nodos_grafos[id_expresion] = nodo_expr
	
	if id_expresion > programa_de_usuario.ultimo_id:
		programa_de_usuario.ultimo_id = id_expresion
		
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	if nodo_destino:
		nodo_destino.entradas_datos_conectadas[parametro_destino] = {
			"fuente": "REFERENCIA_NODO",
			"id_origen": id_expresion,
			"puerto": "resultado"
		}
		
	programa_de_usuario.limpiar_expresiones_huerfanas()
	renderizar_grafo_completo()

# --- EXPORTACIÓN A DISCO DEL JSON IR ---
func compilar() -> void:
	var json_generado = programa_de_usuario.generar_json_ir()
	print("--- JSON GENERADO PARA JAVA ---")
	print(json_generado)
	
	# 1. Guardar localmente en el proyecto Godot
	var ruta_local : String = "res://flujo_salida.json"
	var file_local := FileAccess.open(ruta_local, FileAccess.WRITE)
	if file_local:
		file_local.store_string(json_generado)
		file_local.close()
		
	# 2. Si existe la carpeta del Compilador Java en el repositorio, actualizar flujo_prueba.json directamente
	var ruta_java_relativa : String = ProjectSettings.globalize_path("res://../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/flujo_prueba.json")
	var ruta_mostrada : String = ProjectSettings.globalize_path(ruta_local)
	
	if FileAccess.file_exists(ruta_java_relativa):
		var file_java := FileAccess.open(ruta_java_relativa, FileAccess.WRITE)
		if file_java:
			file_java.store_string(json_generado)
			file_java.close()
			ruta_mostrada = ruta_java_relativa
			
	compilacion_exitosa.emit(ruta_mostrada)
