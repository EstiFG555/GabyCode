extends Node
class_name GestorEditor

signal grafo_actualizado
signal compilacion_exitosa(ruta_archivo: String)

const RUTA_CATALOGO_JSON : String = "res://catalogo_host.json"
const CARPETA_PROGRAMAS : String = "res://programas/"
const CARPETA_SUBRUTINAS : String = "res://subrutinas/"

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
var subrutinas_registradas_ids : Array[StringName] = []

func _ready() -> void:
	programa_de_usuario = ASG_Programa.new()
	_asegurar_directorios()
	recargar_catalogo_completo()

func _asegurar_directorios() -> void:
	for dir_path in [CARPETA_PROGRAMAS, CARPETA_SUBRUTINAS]:
		var abs_path := ProjectSettings.globalize_path(dir_path)
		if not DirAccess.dir_exists_absolute(abs_path):
			DirAccess.make_dir_recursive_absolute(abs_path)

func recargar_catalogo_completo() -> void:
	registro_bloques.clear()
	subrutinas_registradas_ids.clear()
	_cargar_definiciones_nativas_lenguaje()
	_cargar_catalogo_host_json()
	_cargar_subrutinas_disco()
	renderizar_grafo_completo()

func _cargar_definiciones_nativas_lenguaje() -> void:
	_registrar_def("Asignar Variable (SET)", GabyEnums.CategoriaNodo.ACCIÓN, &"SET_VAR", {
		&"variable_destino": GabyEnums.TipoDato.ANY,
		&"valor": GabyEnums.TipoDato.ANY
	}, {})
	
	# Bloque nativo para devolver el resultado de una Subrutina
	_registrar_def("Retornar Valor (RETURN)", GabyEnums.CategoriaNodo.ACCIÓN, &"RETURN_VAL", {
		&"valor_retorno": GabyEnums.TipoDato.ANY
	}, {})
	
	_registrar_def("Condición (Si / Si No)", GabyEnums.CategoriaNodo.CONTROL, &"IF_ELSE", {
		&"condicion": GabyEnums.TipoDato.BOOLEAN
	}, {})
	
	_registrar_def("Bucle (Mientras / While)", GabyEnums.CategoriaNodo.CONTROL, &"WHILE", {
		&"condicion": GabyEnums.TipoDato.BOOLEAN
	}, {})
	
	_registrar_def("Control: Por cada elemento (ForEach)", GabyEnums.CategoriaNodo.CONTROL, &"FOREACH", {
		&"coleccion": GabyEnums.TipoDato.ARRAY
	}, {
		&"elemento_actual": GabyEnums.TipoDato.ANY
	})
	
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

func _cargar_catalogo_host_json() -> void:
	if not FileAccess.file_exists(RUTA_CATALOGO_JSON):
		return
	var file := FileAccess.open(RUTA_CATALOGO_JSON, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return
	
	if data.has("tipos_objetos"):
		for nombre_obj in data["tipos_objetos"]:
			GabyEnums.registrar_tipo_objeto(str(nombre_obj))
			
	if data.has("eventos"):
		for ev in data["eventos"]:
			var op := StringName(str(ev.get("operacion", "")))
			var nom := str(ev.get("nombre_visual", op))
			var salidas_dict : Dictionary = {}
			var subtipos_dict : Dictionary = {}
			var raw_salidas : Dictionary = ev.get("salidas", {})
			for k in raw_salidas.keys():
				var info = raw_salidas[k]
				if typeof(info) == TYPE_DICTIONARY:
					salidas_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("tipo", "ANY")))
					if info.has("subtipo"):
						subtipos_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("subtipo", "ANY")))
				else:
					salidas_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info))
			if op == &"SUBROUTINE_ENTRY":
				salidas_dict.clear()
				subtipos_dict.clear()
			_registrar_def(nom, GabyEnums.CategoriaNodo.EVENTO, op, {}, salidas_dict, subtipos_dict)
			
	if data.has("acciones"):
		for acc in data["acciones"]:
			var op := StringName(str(acc.get("operacion", "")))
			var nom := str(acc.get("nombre_visual", op))
			var entradas_dict : Dictionary = {}
			var raw_entradas : Dictionary = acc.get("entradas", {})
			for k in raw_entradas.keys():
				entradas_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(raw_entradas[k]))
				
			var salidas_dict : Dictionary = {}
			var subtipos_dict : Dictionary = {}
			var raw_salidas : Dictionary = acc.get("salidas", {})
			for k in raw_salidas.keys():
				var info = raw_salidas[k]
				if typeof(info) == TYPE_DICTIONARY:
					salidas_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("tipo", "ANY")))
					if info.has("subtipo"):
						subtipos_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("subtipo", "ANY")))
				else:
					salidas_dict[StringName(k)] = GabyEnums.obtener_id_tipo(str(info))
			_registrar_def(nom, GabyEnums.CategoriaNodo.ACCIÓN, op, entradas_dict, salidas_dict, subtipos_dict)

func _registrar_def(nombre: String, cat: GabyEnums.CategoriaNodo, op: StringName, entradas: Dictionary, salidas: Dictionary, subtipos_salidas: Dictionary = {}) -> DefinicionBloque:
	var def := DefinicionBloque.new()
	def.nombre_visual = nombre
	def.categoria = cat
	def.operacion_host = op
	var ent_tipadas : Dictionary[StringName, int] = {}
	for k in entradas.keys(): ent_tipadas[StringName(k)] = int(entradas[k])
	var sal_tipadas : Dictionary[StringName, int] = {}
	for k in salidas.keys(): sal_tipadas[StringName(k)] = int(salidas[k])
	var sub_tipadas : Dictionary[StringName, int] = {}
	for k in subtipos_salidas.keys(): sub_tipadas[StringName(k)] = int(subtipos_salidas[k])
	
	def.tipos_entradas_esperadas = ent_tipadas
	def.tipos_salidas_provistas = sal_tipadas
	def.subtipos_array_salidas = sub_tipadas
	registro_bloques[op] = def
	return def

# --- GESTIÓN DE PARÁMETROS Y RETORNO EN SUBROUTINE_ENTRY ---
func es_flujo_actual_subrutina() -> bool:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	return ev != null and ev.nombre_evento == &"SUBROUTINE_ENTRY"

func configurar_retorno_subrutina(tipo_ret: int, subtipo_ret: int = GabyEnums.TipoDato.ANY) -> void:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev or ev.nombre_evento != &"SUBROUTINE_ENTRY":
		return
	if ev.tipo_retorno_subrutina == tipo_ret and ev.subtipo_retorno_subrutina == subtipo_ret:
		return
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Configurar Retorno de Subrutina")
	historial.add_do_method(_ejecutar_configurar_retorno_sub.bind(tipo_ret, subtipo_ret))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _ejecutar_configurar_retorno_sub(tipo_ret: int, subtipo_ret: int) -> void:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev: return
	ev.tipo_retorno_subrutina = tipo_ret
	ev.subtipo_retorno_subrutina = subtipo_ret
	
	# Limpiar conexiones previas en bloques RETURN_VAL si cambió el tipo de retorno
	for id_n in programa_de_usuario.nodos_grafos.keys():
		var n := programa_de_usuario.obtener_nodo(id_n)
		if n is ASGAcción and n.nombre_acción == &"RETURN_VAL":
			n.entradas_datos_conectadas.erase(&"valor_retorno")
			
	programa_de_usuario.limpiar_expresiones_huerfanas()
	renderizar_grafo_completo()

func agregar_parametro_entrada_subrutina(nombre_raw: String, tipo: int, subtipo: int = GabyEnums.TipoDato.ANY) -> bool:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev or ev.nombre_evento != &"SUBROUTINE_ENTRY":
		return false
	var nom_limpio := nombre_raw.strip_edges().to_lower().replace(" ", "_")
	if nom_limpio == "" or ev.tipos_salidas_provistas.has(StringName(nom_limpio)):
		return false
		
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Añadir Parámetro de Subrutina")
	historial.add_do_method(_ejecutar_agregar_param_subrutina.bind(nom_limpio, tipo, subtipo))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()
	return true

func _ejecutar_agregar_param_subrutina(nom_limpio: String, tipo: int, subtipo: int) -> void:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev: return
	var clave := StringName(nom_limpio)
	ev.tipos_salidas_provistas[clave] = tipo
	if tipo == GabyEnums.TipoDato.ARRAY:
		ev.subtipos_array_salidas[clave] = subtipo
	if not ev.orden_parametros_subrutina.has(nom_limpio):
		ev.orden_parametros_subrutina.append(nom_limpio)
	renderizar_grafo_completo()

func eliminar_parametro_entrada_subrutina(nom_param: String) -> void:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev or ev.nombre_evento != &"SUBROUTINE_ENTRY":
		return
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Quitar Parámetro de Subrutina")
	historial.add_do_method(_ejecutar_eliminar_param_subrutina.bind(nom_param))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()

func _ejecutar_eliminar_param_subrutina(nom_param: String) -> void:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev: return
	var clave := StringName(nom_param)
	ev.tipos_salidas_provistas.erase(clave)
	ev.subtipos_array_salidas.erase(clave)
	ev.orden_parametros_subrutina.erase(nom_param)
	
	for id_n in programa_de_usuario.nodos_grafos.keys():
		var n := programa_de_usuario.obtener_nodo(id_n)
		var borrar : Array = []
		for p in n.entradas_datos_conectadas.keys():
			var con = n.entradas_datos_conectadas[p]
			if typeof(con) == TYPE_DICTIONARY and con.get("fuente") == "REFERENCIA_NODO":
				if int(con.get("id_origen", -1)) == ev.id and str(con.get("puerto", "")) == nom_param:
					borrar.append(p)
		for p in borrar:
			n.entradas_datos_conectadas.erase(p)
	renderizar_grafo_completo()

func guardar_programa_actual_como_subrutina(nombre_visual: String, codigo_subrutina: String) -> bool:
	var ev := programa_de_usuario.obtener_nodo_evento_raiz()
	if not ev or ev.nombre_evento != &"SUBROUTINE_ENTRY":
		push_warning("Para guardar como Subrutina, el evento raíz del lienzo debe ser 'Inicio de Subrutina (SUBROUTINE_ENTRY)'.")
		return false
		
	var op_limpia := codigo_subrutina.strip_edges().to_upper().replace(" ", "_")
	if not op_limpia.begins_with("SUB_"):
		op_limpia = "SUB_" + op_limpia
	if nombre_visual.strip_edges() == "" or op_limpia == "SUB_":
		return false
		
	var entradas_sub : Dictionary = {}
	var entradas_json : Dictionary = {}
	var orden_entradas : Array = []
	
	for nom_p in ev.orden_parametros_subrutina:
		var clave := StringName(nom_p)
		if ev.tipos_salidas_provistas.has(clave):
			var t_id : int = ev.tipos_salidas_provistas[clave]
			entradas_sub[clave] = t_id
			entradas_json[nom_p] = GabyEnums.obtener_nombre_codigo(t_id)
			orden_entradas.append(nom_p)
			
	# Exportar la firma de retorno (salida "resultado") si la subrutina devuelve un valor
	var salidas_sub : Dictionary = {}
	var subtipos_sal_sub : Dictionary = {}
	var salidas_json : Dictionary = {}
	if ev.tipo_retorno_subrutina != -1:
		salidas_sub[&"resultado"] = ev.tipo_retorno_subrutina
		var info_ret : Dictionary = {"tipo": GabyEnums.obtener_nombre_codigo(ev.tipo_retorno_subrutina)}
		if ev.tipo_retorno_subrutina == GabyEnums.TipoDato.ARRAY:
			subtipos_sal_sub[&"resultado"] = ev.subtipo_retorno_subrutina
			info_ret["subtipo"] = GabyEnums.obtener_nombre_codigo(ev.subtipo_retorno_subrutina)
		salidas_json["resultado"] = info_ret
			
	var ruta_sub := CARPETA_SUBRUTINAS + op_limpia.to_lower() + ".json"
	var exportacion : Dictionary = {
		"nombre_visual": "[Subrutina] " + nombre_visual.strip_edges(),
		"operacion": op_limpia,
		"orden_entradas": orden_entradas,
		"entradas": entradas_json,
		"salidas": salidas_json,
		"grafo": JSON.parse_string(programa_de_usuario.generar_json_ir())
	}
	var f := FileAccess.open(ruta_sub, FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(exportacion, "\t"))
	f.close()
	
	var def := _registrar_def("[Subrutina] " + nombre_visual.strip_edges(), GabyEnums.CategoriaNodo.ACCIÓN, StringName(op_limpia), entradas_sub, salidas_sub, subtipos_sal_sub)
	def.es_subrutina = true
	if not subrutinas_registradas_ids.has(StringName(op_limpia)):
		subrutinas_registradas_ids.append(StringName(op_limpia))
	grafo_actualizado.emit()
	compilacion_exitosa.emit(ProjectSettings.globalize_path(ruta_sub))
	return true

func _cargar_subrutinas_disco() -> void:
	var dir := DirAccess.open(CARPETA_SUBRUTINAS)
	if not dir: return
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if not dir.current_is_dir() and archivo.ends_with(".json"):
			var f := FileAccess.open(CARPETA_SUBRUTINAS + archivo, FileAccess.READ)
			if f:
				var data = JSON.parse_string(f.get_as_text())
				f.close()
				if typeof(data) == TYPE_DICTIONARY and data.has("operacion"):
					var op := StringName(str(data["operacion"]))
					var nom := str(data.get("nombre_visual", op))
					var entradas_sub : Dictionary = {}
					if data.has("entradas") and typeof(data["entradas"]) == TYPE_DICTIONARY:
						var ent_dict : Dictionary = data["entradas"]
						for k in ent_dict.keys():
							entradas_sub[StringName(k)] = GabyEnums.obtener_id_tipo(str(ent_dict[k]))
							
					var salidas_sub : Dictionary = {}
					var subtipos_sub : Dictionary = {}
					if data.has("salidas") and typeof(data["salidas"]) == TYPE_DICTIONARY:
						var sal_dict : Dictionary = data["salidas"]
						for k in sal_dict.keys():
							var info = sal_dict[k]
							if typeof(info) == TYPE_DICTIONARY:
								salidas_sub[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("tipo", "ANY")))
								if info.has("subtipo"):
									subtipos_sub[StringName(k)] = GabyEnums.obtener_id_tipo(str(info.get("subtipo", "ANY")))
							else:
								salidas_sub[StringName(k)] = GabyEnums.obtener_id_tipo(str(info))
								
					var def := _registrar_def(nom, GabyEnums.CategoriaNodo.ACCIÓN, op, entradas_sub, salidas_sub, subtipos_sub)
					def.es_subrutina = true
					if not subrutinas_registradas_ids.has(op):
						subrutinas_registradas_ids.append(op)
		archivo = dir.get_next()
	dir.list_dir_end()

func cargar_subrutina_en_lienzo(op_name: StringName) -> void:
	var ruta := CARPETA_SUBRUTINAS + String(op_name).to_lower() + ".json"
	cargar_programa_desde_ruta(ruta)

func eliminar_subrutina_guardada(op_name: StringName) -> void:
	if not subrutinas_registradas_ids.has(op_name):
		return
	subrutinas_registradas_ids.erase(op_name)
	registro_bloques.erase(op_name)
	var ruta := CARPETA_SUBRUTINAS + String(op_name).to_lower() + ".json"
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	renderizar_grafo_completo()

# --- GUARDAR Y CARGAR PROGRAMAS COMPLETOS (.JSON) ---
func limpiar_lienzo_nuevo_programa() -> void:
	programa_de_usuario = ASG_Programa.new()
	historial.clear_history()
	id_padre_pendiente = -1
	renderizar_grafo_completo()

func guardar_programa_en_disco(nombre_archivo: String) -> String:
	var nom_limpio := nombre_archivo.strip_edges().replace(" ", "_")
	if nom_limpio == "": nom_limpio = "programa_guardado"
	if not nom_limpio.ends_with(".json"): nom_limpio += ".json"
	
	var ruta := CARPETA_PROGRAMAS + nom_limpio
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f:
		f.store_string(programa_de_usuario.generar_json_ir())
		f.close()
	return ProjectSettings.globalize_path(ruta)

func cargar_programa_desde_ruta(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta): return false
	var f := FileAccess.open(ruta, FileAccess.READ)
	if not f: return false
	var contenido := f.get_as_text()
	f.close()
	
	if programa_de_usuario.cargar_desde_json_string(contenido, registro_bloques, fabrica_de_bloques):
		historial.clear_history()
		id_padre_pendiente = -1
		renderizar_grafo_completo()
		return true
	return false

# --- COMANDOS DE VARIABLES LOCALES ---
func crear_variable_local(nombre: String, tipo: int, valor_inicial: Variant, subtipo: int = GabyEnums.TipoDato.ANY) -> bool:
	var nombre_limpio = nombre.strip_edges().replace(" ", "_")
	if nombre_limpio == "" or programa_de_usuario.existe_variable(nombre_limpio):
		return false
		
	var instantanea_previa = programa_de_usuario.crear_instantanea()
	historial.create_action("Crear Variable " + nombre_limpio)
	historial.add_do_method(_ejecutar_crear_variable.bind(nombre_limpio, tipo, valor_inicial, subtipo))
	historial.add_undo_method(_ejecutar_restaurar_instantanea.bind(instantanea_previa, id_padre_pendiente, puerto_pendiente))
	historial.commit_action()
	return true

func _ejecutar_crear_variable(nombre: String, tipo: int, valor_inicial: Variant, subtipo: int) -> void:
	programa_de_usuario.agregar_variable(nombre, tipo, valor_inicial, subtipo)
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
	nuevo_nodo.subtipos_array_salidas = definicion.subtipos_array_salidas.duplicate()
	
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

func _inferir_tipo_salida_nodo(nodo_cand: NodoBaseASG, nombre_salida: StringName) -> int:
	var tipo_base : int = nodo_cand.tipos_salidas_provistas.get(nombre_salida, GabyEnums.TipoDato.ANY)
	if nodo_cand is ASGControl and nodo_cand.nombre_control == &"FOREACH" and nombre_salida == &"elemento_actual":
		if nodo_cand.entradas_datos_conectadas.has(&"coleccion"):
			var con_col = nodo_cand.entradas_datos_conectadas[&"coleccion"]
			if typeof(con_col) == TYPE_DICTIONARY:
				if con_col.get("fuente") == "REFERENCIA_NODO":
					var nodo_orig = programa_de_usuario.obtener_nodo(int(con_col.get("id_origen", -1)))
					var puerto_orig := StringName(str(con_col.get("puerto", "")))
					if nodo_orig and nodo_orig.subtipos_array_salidas.has(puerto_orig):
						return nodo_orig.subtipos_array_salidas[puerto_orig]
				elif con_col.get("fuente") == "VARIABLE":
					return programa_de_usuario.obtener_subtipo_variable(str(con_col.get("nombre", "")))
	return tipo_base

# Calcula el diccionario de tipos de entrada efectivos de un nodo (para SET_VAR y RETURN_VAL)
func _obtener_entradas_efectivas_nodo(nodo: NodoBaseASG) -> Dictionary:
	var copia : Dictionary = nodo.tipos_entradas_esperadas.duplicate()
	if nodo is ASGAcción:
		if nodo.nombre_acción == &"SET_VAR" and nodo.entradas_datos_conectadas.has(&"variable_destino"):
			var con_var = nodo.entradas_datos_conectadas[&"variable_destino"]
			if typeof(con_var) == TYPE_DICTIONARY and con_var.get("fuente") == "VARIABLE":
				copia[&"valor"] = programa_de_usuario.obtener_tipo_variable(str(con_var.get("nombre", "")))
		elif nodo.nombre_acción == &"RETURN_VAL":
			var ev := programa_de_usuario.obtener_nodo_evento_raiz()
			if ev and ev.nombre_evento == &"SUBROUTINE_ENTRY" and ev.tipo_retorno_subrutina != -1:
				copia[&"valor_retorno"] = ev.tipo_retorno_subrutina
	return copia

func buscar_opciones_compatibles(id_destino: int, parametro: StringName, tipo_forzado: int = -1) -> Array:
	var opciones : Array = []
	var nodo_destino = programa_de_usuario.obtener_nodo(id_destino)
	
	if parametro == &"variable_destino":
		for variable in programa_de_usuario.variables_locales:
			opciones.append({
				"texto_mostrar": "[Var] " + str(variable.get("nombre", "SinNombre")),
				"datos_conexion": {"fuente": "VARIABLE", "nombre": variable.get("nombre")}
			})
		return opciones
	
	var tipo_req : int = tipo_forzado
	if tipo_req == -1:
		if not nodo_destino: return opciones
		var entradas_efectivas := _obtener_entradas_efectivas_nodo(nodo_destino)
		tipo_req = entradas_efectivas.get(parametro, GabyEnums.TipoDato.ANY)
	
	# 1. Variables locales compatibles
	for variable in programa_de_usuario.variables_locales:
		var tipo_var : int = int(variable.get("tipo", GabyEnums.TipoDato.ANY))
		if GabyEnums.son_compatibles(tipo_var, tipo_req):
			opciones.append({
				"texto_mostrar": "[Var] " + str(variable.get("nombre", "SinNombre")),
				"datos_conexion": {"fuente": "VARIABLE", "nombre": variable.get("nombre")}
			})
			
	# 2. Salidas EXCLUSIVAMENTE de nodos ancestros
	var ids_ancestros : Array[int] = programa_de_usuario.obtener_ancestros_de_nodo(id_destino)
	for id_candidato in ids_ancestros:
		var nodo_cand = programa_de_usuario.obtener_nodo(id_candidato)
		if not nodo_cand or nodo_cand.categoria == GabyEnums.CategoriaNodo.EXPRESION:
			continue
		
		for nombre_salida in nodo_cand.tipos_salidas_provistas.keys():
			var tipo_salida : int = _inferir_tipo_salida_nodo(nodo_cand, nombre_salida)
			if GabyEnums.son_compatibles(tipo_salida, tipo_req):
				var etiqueta_tipo := GabyEnums.obtener_nombre_codigo(tipo_salida)
				opciones.append({
					"texto_mostrar": "[Salida #%d: %s (%s)]" % [id_candidato, String(nombre_salida), etiqueta_tipo],
					"datos_conexion": {"fuente": "REFERENCIA_NODO", "id_origen": id_candidato, "puerto": String(nombre_salida)}
				})
				
	# 3. Mostrar expresión propia ya conectada
	if nodo_destino and nodo_destino.entradas_datos_conectadas.has(parametro):
		var con = nodo_destino.entradas_datos_conectadas[parametro]
		if typeof(con) == TYPE_DICTIONARY and con.get("fuente") == "REFERENCIA_NODO":
			var id_orig = int(con.get("id_origen", -1))
			var nodo_orig = programa_de_usuario.obtener_nodo(id_orig)
			if nodo_orig and nodo_orig.categoria == GabyEnums.CategoriaNodo.EXPRESION:
				opciones.append({
					"texto_mostrar": "[Fórmula #" + str(id_orig) + "] " + str(nodo_orig.nombre_expresión),
					"datos_conexion": {"fuente": "REFERENCIA_NODO", "id_origen": id_orig, "puerto": "resultado"}
				})
	
	# 4. Opción para crear nuevas fórmulas
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
	nuevo_nodo.subtipos_array_salidas = definicion.subtipos_array_salidas.duplicate()
	
	programa_de_usuario.mutar_nodo(id_nodo, nuevo_nodo)
	renderizar_grafo_completo()

func obtener_definiciones_validas() -> Array:
	var validas: Array = []
	var ev_raiz := programa_de_usuario.obtener_nodo_evento_raiz()
	var tiene_evento_inicial: bool = (ev_raiz != null)
	
	for key in registro_bloques.keys():
		var def: DefinicionBloque = registro_bloques[key]
		if def.categoria == GabyEnums.CategoriaNodo.EXPRESION:
			continue
		# El bloque RETURN_VAL solo es válido dentro de una Subrutina que tenga un tipo de retorno configurado
		if key == &"RETURN_VAL":
			if not ev_raiz or ev_raiz.nombre_evento != &"SUBROUTINE_ENTRY" or ev_raiz.tipo_retorno_subrutina == -1:
				continue
		if not tiene_evento_inicial and def.categoria == GabyEnums.CategoriaNodo.EVENTO:
			validas.append(def)
		elif tiene_evento_inicial and def.categoria != GabyEnums.CategoriaNodo.EVENTO:
			validas.append(def)
			
	return validas

func obtener_definiciones_para_mutacion(categoria_actual : GabyEnums.CategoriaNodo) -> Array:
	var validas : Array = []
	var ev_raiz := programa_de_usuario.obtener_nodo_evento_raiz()
	for key in registro_bloques.keys():
		var def : DefinicionBloque = registro_bloques[key]
		if key == &"RETURN_VAL":
			if not ev_raiz or ev_raiz.nombre_evento != &"SUBROUTINE_ENTRY" or ev_raiz.tipo_retorno_subrutina == -1:
				continue
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
			
	var ev_raiz := programa_de_usuario.obtener_nodo_evento_raiz()
	if ev_raiz:
		_renderizar_secuencia(ev_raiz.id, contenedor_flujo_ui)
		
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
		
		if not es_primero_en_secuencia or contenedor_destino != contenedor_flujo_ui:
			var flecha := _crear_conector_flecha()
			contenedor_destino.add_child(flecha)
		es_primero_en_secuencia = false
		
		var bloque_ui : BloqueBaseUI = fabrica_de_bloques.construir_bloque_ui(definicion.categoria)
		contenedor_destino.add_child(bloque_ui)
			
		var func_busqueda = Callable(self, "buscar_opciones_compatibles")
		var titulo_mostrar := "[#%d] %s" % [id_actual, definicion.nombre_visual]
		var entradas_efectivas := _obtener_entradas_efectivas_nodo(nodo)
		bloque_ui.inicializar(id_actual, titulo_mostrar, entradas_efectivas, func_busqueda, nodo.entradas_datos_conectadas)
		
		if bloque_ui is BloqueEventoUI and nodo is ASGEvento:
			bloque_ui.mostrar_salidas_contexto(
				nodo.tipos_salidas_provistas,
				nodo.subtipos_array_salidas,
				operacion_host == &"SUBROUTINE_ENTRY",
				nodo.tipo_retorno_subrutina,
				nodo.subtipo_retorno_subrutina
			)
			bloque_ui.solicitar_eliminar_parametro_subrutina.connect(eliminar_parametro_entrada_subrutina)
		
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

func compilar() -> void:
	var json_generado = programa_de_usuario.generar_json_ir()
	print("--- JSON GENERADO PARA JAVA ---")
	print(json_generado)
	
	var ruta_local : String = "res://flujo_salida.json"
	var file_local := FileAccess.open(ruta_local, FileAccess.WRITE)
	if file_local:
		file_local.store_string(json_generado)
		file_local.close()
		
	var ruta_java_relativa : String = ProjectSettings.globalize_path("res://../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/flujo_prueba.json")
	var ruta_mostrada : String = ProjectSettings.globalize_path(ruta_local)
	
	if FileAccess.file_exists(ruta_java_relativa):
		var file_java := FileAccess.open(ruta_java_relativa, FileAccess.WRITE)
		if file_java:
			file_java.store_string(json_generado)
			file_java.close()
			ruta_mostrada = ruta_java_relativa
			
	compilacion_exitosa.emit(ruta_mostrada)
