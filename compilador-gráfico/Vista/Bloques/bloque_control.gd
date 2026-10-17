extends BloqueBaseUI
class_name BloqueControlUI

signal solicitar_insercion_rama(id_padre: int, puerto: StringName)

@export var contenedor_parametros : VBoxContainer
@export var rama_verdadera : VBoxContainer
@export var rama_falsa : VBoxContainer
@export var boton_agregar_verdadero : Button
@export var boton_agregar_falso : Button

func inicializar(id_asignado : int, titulo : String, entradas_esperadas : Dictionary, funcion_buscar_opciones : Callable, estado_guardado : Dictionary = {}) -> void:
	super.inicializar(id_asignado, titulo, entradas_esperadas, funcion_buscar_opciones, estado_guardado)
	
	if boton_agregar_verdadero and not boton_agregar_verdadero.pressed.is_connected(_on_agregar_verdadero):
		boton_agregar_verdadero.pressed.connect(_on_agregar_verdadero)
		
	if boton_agregar_falso and not boton_agregar_falso.pressed.is_connected(_on_agregar_falso):
		boton_agregar_falso.pressed.connect(_on_agregar_falso)
	
	for hijo in contenedor_parametros.get_children():
		hijo.queue_free()
		
	for nombre_parametro in entradas_esperadas.keys():
		var tipo_req = entradas_esperadas[nombre_parametro]
		
		var fila := HBoxContainer.new()
		
		var label_param := Label.new()
		label_param.text = str(nombre_parametro).capitalize() + ":"
		label_param.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label_param)
		
		var option_btn := OptionButton.new()
		option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_btn.add_item("Conectar...")
		option_btn.set_item_metadata(0, null)
		
		var literal_input := LineEdit.new()
		literal_input.placeholder_text = "Literal..."
		literal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var opciones_validas : Array = funcion_buscar_opciones.call(id_logico, nombre_parametro)
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
		
		option_btn.item_selected.connect(func(index: int):
			var valor = option_btn.get_item_metadata(index)
			if index > 0: literal_input.text = "" 
			
			if typeof(valor) == TYPE_DICTIONARY and valor.get("fuente") == "CREAR_EXPRESION":
				solicitar_creacion_expresion.emit(id_logico, nombre_parametro, valor.get("tipo_esperado"))
				option_btn.select(indice_a_seleccionar)
			else:
				parametro_modificado.emit(id_logico, nombre_parametro, valor)
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

func _on_agregar_verdadero() -> void:
	solicitar_insercion_rama.emit(id_logico, &"id_rama_verdadera")

func _on_agregar_falso() -> void:
	solicitar_insercion_rama.emit(id_logico, &"id_rama_falsa")

func _procesar_ingreso_literal(nuevo_texto: String, texto_viejo: String, option_btn: OptionButton, tipo_req: int, parametro: StringName) -> void:
	if nuevo_texto == texto_viejo: return
	
	if nuevo_texto.strip_edges() != "":
		option_btn.select(0)
		var valor_casteado = _castear_literal(nuevo_texto, tipo_req)
		parametro_modificado.emit(id_logico, parametro, {"fuente": "LITERAL", "valor": valor_casteado})
	elif texto_viejo != "":
		parametro_modificado.emit(id_logico, parametro, null)

func _castear_literal(texto: String, tipo_esperado: GabyEnums.TipoDato) -> Variant:
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
