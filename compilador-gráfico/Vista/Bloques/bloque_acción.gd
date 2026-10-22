extends BloqueBaseUI
class_name BloqueAccionUI

@export var contenedor_parametros : VBoxContainer

func inicializar(id_asignado : int, titulo : String, entradas_esperadas : Dictionary, funcion_buscar_opciones : Callable, estado_guardado : Dictionary = {}) -> void:
	super.inicializar(id_asignado, titulo, entradas_esperadas, funcion_buscar_opciones, estado_guardado)
	
	for hijo in contenedor_parametros.get_children():
		hijo.queue_free()
		
	for nombre_parametro in entradas_esperadas.keys():
		var tipo_req : int = entradas_esperadas[nombre_parametro]
		var es_selector_variable_destino : bool = (nombre_parametro == &"variable_destino" or nombre_parametro == &"variable_iteradora")
		
		var fila := HBoxContainer.new()
		
		var label_param := Label.new()
		label_param.text = str(nombre_parametro).capitalize() + ":"
		label_param.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label_param)
		
		var opciones_validas : Array = funcion_buscar_opciones.call(id_logico, nombre_parametro)
		for opcion in opciones_validas:
			if opcion["datos_conexion"].get("fuente") == "CREAR_EXPRESION":
				tipo_req = opcion["datos_conexion"].get("tipo_esperado", tipo_req)
				
		var permite_literal : bool = (not es_selector_variable_destino) and _es_tipo_literal_permitido(tipo_req)
		
		var option_btn := OptionButton.new()
		option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if es_selector_variable_destino:
			option_btn.add_item("Elegir Variable...")
		elif permite_literal:
			option_btn.add_item("[ ✏️ Escribir Literal ]")
		else:
			option_btn.add_item("Conectar (" + GabyEnums.obtener_nombre_codigo(tipo_req) + ")...")
		option_btn.set_item_metadata(0, null)
		
		var literal_input := LineEdit.new()
		literal_input.placeholder_text = "Valor " + GabyEnums.obtener_nombre_codigo(tipo_req) + "..."
		literal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var idx : int = 1
		var indice_a_seleccionar : int = 0
		
		for opcion in opciones_validas:
			option_btn.add_item(opcion["texto_mostrar"])
			option_btn.set_item_metadata(idx, opcion["datos_conexion"])
			
			if estado_guardado.has(nombre_parametro):
				var conexion_guardada : Variant = estado_guardado[nombre_parametro]
				if typeof(conexion_guardada) == TYPE_DICTIONARY and _son_conexiones_iguales(conexion_guardada, opcion["datos_conexion"]):
					indice_a_seleccionar = idx
			idx += 1
		
		option_btn.select(indice_a_seleccionar)
		
		var literal_guardado_str = ""
		if estado_guardado.has(nombre_parametro):
			var conexion_guardada = estado_guardado[nombre_parametro]
			if typeof(conexion_guardada) == TYPE_DICTIONARY and conexion_guardada.get("fuente") == "LITERAL":
				literal_guardado_str = str(conexion_guardada.get("valor"))
				literal_input.text = literal_guardado_str
				
		# EXCLUSIÓN MUTUA VISUAL: Solo mostrar LineEdit si permite literal y NO hay conexión activa
		literal_input.visible = permite_literal and (indice_a_seleccionar == 0)
		
		option_btn.item_selected.connect(func(index: int):
			var valor = option_btn.get_item_metadata(index)
			if typeof(valor) == TYPE_DICTIONARY and valor.get("fuente") == "CREAR_EXPRESION":
				solicitar_creacion_expresion.emit(id_logico, nombre_parametro, valor.get("tipo_esperado"))
				option_btn.select(indice_a_seleccionar)
				return
				
			if index > 0:
				literal_input.text = ""
				literal_input.hide()
				parametro_modificado.emit(id_logico, nombre_parametro, valor)
			else:
				literal_input.visible = permite_literal
				parametro_modificado.emit(id_logico, nombre_parametro, null)
		)
		
		literal_input.text_submitted.connect(func(new_text: String):
			_procesar_ingreso_literal(new_text, literal_guardado_str, option_btn, tipo_req, nombre_parametro)
		)
		
		literal_input.focus_exited.connect(func():
			_procesar_ingreso_literal(literal_input.text, literal_guardado_str, option_btn, tipo_req, nombre_parametro)
		)
		
		fila.add_child(option_btn)
		fila.add_child(literal_input)
		contenedor_parametros.add_child(fila)

func _es_tipo_literal_permitido(tipo_req: int) -> bool:
	return tipo_req in [
		GabyEnums.TipoDato.INT,
		GabyEnums.TipoDato.FLOAT,
		GabyEnums.TipoDato.STRING,
		GabyEnums.TipoDato.BOOLEAN
	]

func _procesar_ingreso_literal(nuevo_texto: String, texto_viejo: String, option_btn: OptionButton, tipo_req: int, parametro: StringName) -> void:
	if not _es_tipo_literal_permitido(tipo_req): return
	if option_btn.selected > 0: return
	if nuevo_texto == texto_viejo: return
	
	if nuevo_texto.strip_edges() != "":
		var valor_casteado = _castear_literal(nuevo_texto, tipo_req)
		parametro_modificado.emit(id_logico, parametro, {"fuente": "LITERAL", "valor": valor_casteado})
	elif texto_viejo != "":
		parametro_modificado.emit(id_logico, parametro, null)

func _castear_literal(texto: String, tipo_esperado: int) -> Variant:
	var txt = texto.strip_edges()
	match tipo_esperado:
		GabyEnums.TipoDato.INT: return txt.to_int()
		GabyEnums.TipoDato.FLOAT: return txt.to_float()
		GabyEnums.TipoDato.BOOLEAN: return txt.to_lower() == "true" or txt == "1"
		_: return txt

func _son_conexiones_iguales(a: Dictionary, b: Dictionary) -> bool:
	if a.get("fuente") != b.get("fuente"): return false
	if a.get("fuente") == "VARIABLE": return a.get("nombre") == b.get("nombre")
	if a.get("fuente") == "REFERENCIA_NODO": return a.get("id_origen") == b.get("id_origen") and a.get("puerto") == b.get("puerto")
	if a.get("fuente") == "LITERAL": return str(a.get("valor")) == str(b.get("valor"))
	return false
