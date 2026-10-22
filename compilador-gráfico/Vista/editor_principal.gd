extends Control

var controlador: GestorEditor

@export var contenedor_bloques: VBoxContainer
@export var boton_agregar: Button
@export var menu_bloques: MenuBloquesUI
@export var scroll_container: ScrollContainer 
@export var modal_expresion: ModalExpresionUI
var haciendo_paneo: bool = false

# Referencias UI del Panel Izquierdo (Variables Locales y Archivos)
var input_nombre_var: LineEdit
var selector_tipo_var: OptionButton
var selector_subtipo_array: OptionButton
var input_valor_var: LineEdit
var contenedor_lista_vars: VBoxContainer
var input_nombre_programa: LineEdit
var dialogo_cargar_json: FileDialog

# Referencias UI del Panel Derecho (Subrutinas del Lienzo y Compilación)
var seccion_parametros_subrutina: VBoxContainer
var lbl_aviso_subrutina: Label
var input_nombre_param_sub: LineEdit
var selector_tipo_param_sub: OptionButton
var selector_subtipo_param_sub: OptionButton
var selector_retorno_sub: OptionButton
var selector_subtipo_retorno_sub: OptionButton
var input_titulo_subrutina: LineEdit
var input_codigo_subrutina: LineEdit
var contenedor_subrutinas_guardadas: VBoxContainer
var label_estado_compilacion: Label

func _ready() -> void:
	controlador = GestorEditor.new()
	add_child(controlador) 
	
	controlador.contenedor_flujo_ui = contenedor_bloques
	controlador.grafo_actualizado.connect(_on_grafo_actualizado)
	controlador.compilacion_exitosa.connect(_on_compilacion_exitosa)
	
	boton_agregar.pressed.connect(_on_boton_agregar_pressed)
	menu_bloques.instruccion_seleccionada.connect(_on_instruccion_seleccionada_en_menu)
	
	_construir_panel_variables_y_archivos_ui()
	_construir_panel_subrutinas_y_compilacion_ui()
	_on_grafo_actualizado()
	
	contenedor_bloques.custom_minimum_size = Vector2(4000, 4000)
	call_deferred("_centrar_camara")

func _on_grafo_actualizado() -> void:
	_actualizar_lista_variables_ui()
	_actualizar_panel_subrutinas_ui()

func _poblar_selector_tipos(selector: OptionButton, incluir_any: bool = false) -> void:
	selector.clear()
	var etiquetas : Dictionary = GabyEnums.obtener_diccionario_etiquetas()
	for tipo_id in etiquetas.keys():
		if not incluir_any and tipo_id == GabyEnums.TipoDato.ANY:
			continue
		selector.add_item(etiquetas[tipo_id])
		selector.set_item_metadata(selector.item_count - 1, tipo_id)

func _poblar_selector_retorno(selector: OptionButton) -> void:
	selector.clear()
	selector.add_item("Sin Retorno (Void)")
	selector.set_item_metadata(0, -1)
	var etiquetas : Dictionary = GabyEnums.obtener_diccionario_etiquetas()
	for tipo_id in etiquetas.keys():
		if tipo_id == GabyEnums.TipoDato.ANY:
			continue
		selector.add_item("Devuelve: " + etiquetas[tipo_id])
		selector.set_item_metadata(selector.item_count - 1, tipo_id)

# --- PANEL IZQUIERDO: GESTOR DE VARIABLES LOCALES + ARCHIVOS DE PROGRAMA ---
func _construir_panel_variables_y_archivos_ui() -> void:
	var panel_izq = get_node_or_null("Organizador/PanelContainer")
	if not panel_izq: return
	
	var margen := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margen.add_theme_constant_override(lado, 10)
	panel_izq.add_child(margen)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margen.add_child(vbox)
	
	var titulo := Label.new()
	titulo.text = "MEMORIA (VARIABLES LOCALES)"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)
	vbox.add_child(HSeparator.new())
	
	input_nombre_var = LineEdit.new()
	input_nombre_var.placeholder_text = "Nombre (ej. Contador)"
	vbox.add_child(input_nombre_var)
	
	selector_tipo_var = OptionButton.new()
	_poblar_selector_tipos(selector_tipo_var)
	vbox.add_child(selector_tipo_var)
	
	selector_subtipo_array = OptionButton.new()
	_poblar_selector_tipos(selector_subtipo_array, true)
	selector_subtipo_array.hide()
	vbox.add_child(selector_subtipo_array)
	
	selector_tipo_var.item_selected.connect(func(idx: int):
		var t_id : int = selector_tipo_var.get_item_metadata(idx)
		selector_subtipo_array.visible = (t_id == GabyEnums.TipoDato.ARRAY)
	)
	
	input_valor_var = LineEdit.new()
	input_valor_var.placeholder_text = "Valor inicial (opcional)"
	vbox.add_child(input_valor_var)
	
	var btn_crear_var := Button.new()
	btn_crear_var.text = "[+ Declarar Variable Local]"
	btn_crear_var.pressed.connect(_on_crear_variable_pressed)
	vbox.add_child(btn_crear_var)
	
	vbox.add_child(HSeparator.new())
	
	var scroll_vars := ScrollContainer.new()
	scroll_vars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_vars)
	
	contenedor_lista_vars = VBoxContainer.new()
	contenedor_lista_vars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vars.add_child(contenedor_lista_vars)
	
	vbox.add_child(HSeparator.new())
	
	var lbl_arch := Label.new()
	lbl_arch.text = "GESTIÓN DE PROGRAMAS (.JSON)"
	lbl_arch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_arch)
	
	var btn_nuevo_prog := Button.new()
	btn_nuevo_prog.text = "[ 🆕 Limpiar Lienzo / Nuevo ]"
	btn_nuevo_prog.pressed.connect(func(): controlador.limpiar_lienzo_nuevo_programa())
	vbox.add_child(btn_nuevo_prog)
	
	input_nombre_programa = LineEdit.new()
	input_nombre_programa.placeholder_text = "Nombre archivo (ej. caso_venta)"
	vbox.add_child(input_nombre_programa)
	
	var btn_guardar_prog := Button.new()
	btn_guardar_prog.text = "[ 💾 Guardar Programa ]"
	btn_guardar_prog.pressed.connect(func():
		var ruta := controlador.guardar_programa_en_disco(input_nombre_programa.text)
		_on_compilacion_exitosa(ruta)
	)
	vbox.add_child(btn_guardar_prog)
	
	var btn_cargar_prog := Button.new()
	btn_cargar_prog.text = "[ 📂 Cargar Programa JSON... ]"
	btn_cargar_prog.pressed.connect(func(): dialogo_cargar_json.popup_centered(Vector2i(650, 420)))
	vbox.add_child(btn_cargar_prog)
	
	dialogo_cargar_json = FileDialog.new()
	dialogo_cargar_json.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialogo_cargar_json.access = FileDialog.ACCESS_FILESYSTEM
	dialogo_cargar_json.filters = PackedStringArray(["*.json ; Archivos JSON GabyCode"])
	dialogo_cargar_json.current_dir = ProjectSettings.globalize_path("res://")
	dialogo_cargar_json.file_selected.connect(func(ruta: String):
		controlador.cargar_programa_desde_ruta(ruta)
	)
	add_child(dialogo_cargar_json)

func _on_crear_variable_pressed() -> void:
	var nombre = input_nombre_var.text.strip_edges()
	if nombre == "": return
	
	var tipo : int = selector_tipo_var.get_item_metadata(selector_tipo_var.selected)
	var subtipo : int = GabyEnums.TipoDato.ANY
	if tipo == GabyEnums.TipoDato.ARRAY:
		subtipo = selector_subtipo_array.get_item_metadata(selector_subtipo_array.selected)
		
	var txt_val = input_valor_var.text.strip_edges()
	var valor_inicial : Variant = 0
	
	match tipo:
		GabyEnums.TipoDato.INT: valor_inicial = txt_val.to_int() if txt_val != "" else 0
		GabyEnums.TipoDato.FLOAT: valor_inicial = txt_val.to_float() if txt_val != "" else 0.0
		GabyEnums.TipoDato.BOOLEAN: valor_inicial = (txt_val.to_lower() == "true" or txt_val == "1")
		GabyEnums.TipoDato.STRING: valor_inicial = txt_val
		_: valor_inicial = txt_val if txt_val != "" else 0
		
	if controlador.crear_variable_local(nombre, tipo, valor_inicial, subtipo):
		input_nombre_var.text = ""
		input_valor_var.text = ""

func _actualizar_lista_variables_ui() -> void:
	if not contenedor_lista_vars: return
	for hijo in contenedor_lista_vars.get_children():
		hijo.queue_free()
		
	for v in controlador.programa_de_usuario.variables_locales:
		var fila := HBoxContainer.new()
		var lbl := Label.new()
		var nombre_var : String = str(v.get("nombre"))
		var tipo_var : int = int(v.get("tipo", GabyEnums.TipoDato.ANY))
		var subtipo_var : int = int(v.get("subtipo", GabyEnums.TipoDato.ANY))
		var val_ini : Variant = v.get("valor_inicial")
		
		var desc_tipo := GabyEnums.obtener_nombre_codigo(tipo_var)
		if tipo_var == GabyEnums.TipoDato.ARRAY:
			desc_tipo += "<" + GabyEnums.obtener_nombre_codigo(subtipo_var) + ">"
			
		lbl.text = "%s (%s) = %s" % [nombre_var, desc_tipo, str(val_ini)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		fila.add_child(lbl)
		
		var btn_del := Button.new()
		btn_del.text = "X"
		btn_del.pressed.connect(func(): controlador.eliminar_variable_local(nombre_var))
		fila.add_child(btn_del)
		
		contenedor_lista_vars.add_child(fila)

# --- PANEL DERECHO: DISEÑADOR DE SUBRUTINAS DEL LIENZO Y COMPILACIÓN ---
func _construir_panel_subrutinas_y_compilacion_ui() -> void:
	var panel_der = get_node_or_null("Organizador/PanelContainer2")
	if not panel_der: return
	
	var margen := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margen.add_theme_constant_override(lado, 10)
	panel_der.add_child(margen)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margen.add_child(vbox)
	
	var titulo := Label.new()
	titulo.text = "SUBRUTINAS (FUNCIONES)"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)
	vbox.add_child(HSeparator.new())
	
	lbl_aviso_subrutina = Label.new()
	lbl_aviso_subrutina.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_aviso_subrutina.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_aviso_subrutina)
	
	seccion_parametros_subrutina = VBoxContainer.new()
	seccion_parametros_subrutina.add_theme_constant_override("separation", 5)
	vbox.add_child(seccion_parametros_subrutina)
	
	var lbl_p := Label.new()
	lbl_p.text = "1. Parámetros de Entrada:"
	lbl_p.add_theme_font_size_override("font_size", 12)
	seccion_parametros_subrutina.add_child(lbl_p)
	
	input_nombre_param_sub = LineEdit.new()
	input_nombre_param_sub.placeholder_text = "Nombre param (ej. prod_entrada)"
	seccion_parametros_subrutina.add_child(input_nombre_param_sub)
	
	selector_tipo_param_sub = OptionButton.new()
	_poblar_selector_tipos(selector_tipo_param_sub)
	seccion_parametros_subrutina.add_child(selector_tipo_param_sub)
	
	selector_subtipo_param_sub = OptionButton.new()
	_poblar_selector_tipos(selector_subtipo_param_sub, true)
	selector_subtipo_param_sub.hide()
	seccion_parametros_subrutina.add_child(selector_subtipo_param_sub)
	
	selector_tipo_param_sub.item_selected.connect(func(idx: int):
		var t_id : int = selector_tipo_param_sub.get_item_metadata(idx)
		selector_subtipo_param_sub.visible = (t_id == GabyEnums.TipoDato.ARRAY)
	)
	
	var btn_add_param_sub := Button.new()
	btn_add_param_sub.text = "[+ Añadir Parámetro de Entrada]"
	btn_add_param_sub.pressed.connect(func():
		var t_id : int = selector_tipo_param_sub.get_item_metadata(selector_tipo_param_sub.selected)
		var sub_id : int = GabyEnums.TipoDato.ANY
		if t_id == GabyEnums.TipoDato.ARRAY:
			sub_id = selector_subtipo_param_sub.get_item_metadata(selector_subtipo_param_sub.selected)
		if controlador.agregar_parametro_entrada_subrutina(input_nombre_param_sub.text, t_id, sub_id):
			input_nombre_param_sub.text = ""
	)
	seccion_parametros_subrutina.add_child(btn_add_param_sub)
	
	seccion_parametros_subrutina.add_child(HSeparator.new())
	
	var lbl_ret := Label.new()
	lbl_ret.text = "2. Tipo de Retorno (Salida):"
	lbl_ret.add_theme_font_size_override("font_size", 12)
	seccion_parametros_subrutina.add_child(lbl_ret)
	
	selector_retorno_sub = OptionButton.new()
	_poblar_selector_retorno(selector_retorno_sub)
	seccion_parametros_subrutina.add_child(selector_retorno_sub)
	
	selector_subtipo_retorno_sub = OptionButton.new()
	_poblar_selector_tipos(selector_subtipo_retorno_sub, true)
	selector_subtipo_retorno_sub.hide()
	seccion_parametros_subrutina.add_child(selector_subtipo_retorno_sub)
	
	selector_retorno_sub.item_selected.connect(func(idx: int):
		var t_ret : int = selector_retorno_sub.get_item_metadata(idx)
		selector_subtipo_retorno_sub.visible = (t_ret == GabyEnums.TipoDato.ARRAY)
		var sub_ret : int = GabyEnums.TipoDato.ANY
		if t_ret == GabyEnums.TipoDato.ARRAY:
			sub_ret = selector_subtipo_retorno_sub.get_item_metadata(selector_subtipo_retorno_sub.selected)
		controlador.configurar_retorno_subrutina(t_ret, sub_ret)
	)
	
	selector_subtipo_retorno_sub.item_selected.connect(func(_idx: int):
		var t_ret : int = selector_retorno_sub.get_item_metadata(selector_retorno_sub.selected)
		var sub_ret : int = selector_subtipo_retorno_sub.get_item_metadata(selector_subtipo_retorno_sub.selected)
		controlador.configurar_retorno_subrutina(t_ret, sub_ret)
	)
	
	seccion_parametros_subrutina.add_child(HSeparator.new())
	
	var lbl_g := Label.new()
	lbl_g.text = "3. Empaquetar Lienzo como Bloque:"
	lbl_g.add_theme_font_size_override("font_size", 12)
	seccion_parametros_subrutina.add_child(lbl_g)
	
	input_titulo_subrutina = LineEdit.new()
	input_titulo_subrutina.placeholder_text = "Nombre Visual (ej. Calcular Promo)"
	seccion_parametros_subrutina.add_child(input_titulo_subrutina)
	
	input_codigo_subrutina = LineEdit.new()
	input_codigo_subrutina.placeholder_text = "Código (ej. CALC_PROMO)"
	seccion_parametros_subrutina.add_child(input_codigo_subrutina)
	
	var btn_guardar_sub := Button.new()
	btn_guardar_sub.text = "[ 🧩 Guardar Lienzo como Subrutina ]"
	btn_guardar_sub.pressed.connect(func():
		if controlador.guardar_programa_actual_como_subrutina(input_titulo_subrutina.text, input_codigo_subrutina.text):
			input_titulo_subrutina.text = ""
			input_codigo_subrutina.text = ""
	)
	seccion_parametros_subrutina.add_child(btn_guardar_sub)
	
	vbox.add_child(HSeparator.new())
	
	var lbl_lista_sub := Label.new()
	lbl_lista_sub.text = "Subrutinas Disponibles:"
	vbox.add_child(lbl_lista_sub)
	
	var scroll_custom := ScrollContainer.new()
	scroll_custom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_custom)
	
	contenedor_subrutinas_guardadas = VBoxContainer.new()
	contenedor_subrutinas_guardadas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_custom.add_child(contenedor_subrutinas_guardadas)
	
	var btn_recargar_cat := Button.new()
	btn_recargar_cat.text = "[ 🔄 Sincronizar catalogo_host.json ]"
	btn_recargar_cat.pressed.connect(func(): controlador.recargar_catalogo_completo())
	vbox.add_child(btn_recargar_cat)
	
	vbox.add_child(HSeparator.new())
	
	var btn_compilar := Button.new()
	btn_compilar.text = "[ ⚙️ COMPILAR A JSON ]"
	btn_compilar.custom_minimum_size = Vector2(0, 40)
	btn_compilar.pressed.connect(func(): controlador.compilar())
	vbox.add_child(btn_compilar)
	
	label_estado_compilacion = Label.new()
	label_estado_compilacion.text = "Listo para compilar (o pulsa Enter)"
	label_estado_compilacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_estado_compilacion.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label_estado_compilacion)

func _actualizar_panel_subrutinas_ui() -> void:
	if not seccion_parametros_subrutina or not lbl_aviso_subrutina:
		return
		
	_poblar_selector_tipos(selector_tipo_var)
	_poblar_selector_tipos(selector_subtipo_array, true)
	_poblar_selector_tipos(selector_tipo_param_sub)
	_poblar_selector_tipos(selector_subtipo_param_sub, true)
	_poblar_selector_retorno(selector_retorno_sub)
	_poblar_selector_tipos(selector_subtipo_retorno_sub, true)
		
	var es_sub := controlador.es_flujo_actual_subrutina()
	seccion_parametros_subrutina.visible = es_sub
	if es_sub:
		lbl_aviso_subrutina.text = "✅ Modo Subrutina Activo: Configura entradas, tipo de retorno (usa el bloque 'Retornar Valor') y guarda el flujo."
		var ev := controlador.programa_de_usuario.obtener_nodo_evento_raiz()
		if ev:
			for i in range(selector_retorno_sub.item_count):
				if int(selector_retorno_sub.get_item_metadata(i)) == ev.tipo_retorno_subrutina:
					selector_retorno_sub.select(i)
					break
			selector_subtipo_retorno_sub.visible = (ev.tipo_retorno_subrutina == GabyEnums.TipoDato.ARRAY)
			if ev.tipo_retorno_subrutina == GabyEnums.TipoDato.ARRAY:
				for i in range(selector_subtipo_retorno_sub.item_count):
					if int(selector_subtipo_retorno_sub.get_item_metadata(i)) == ev.subtipo_retorno_subrutina:
						selector_subtipo_retorno_sub.select(i)
						break
	else:
		lbl_aviso_subrutina.text = "ℹ️ Para crear una Subrutina reutilizable, inicia el lienzo con el evento 'Inicio de Subrutina (Acción Compuesta)'."
		
	for hijo in contenedor_subrutinas_guardadas.get_children():
		hijo.queue_free()
		
	for op_id in controlador.subrutinas_registradas_ids:
		var def : DefinicionBloque = controlador.registro_bloques.get(op_id)
		if not def: continue
		var fila := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = def.nombre_visual
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		fila.add_child(lbl)
		
		var btn_edit := Button.new()
		btn_edit.text = "📂"
		btn_edit.tooltip_text = "Cargar subrutina en el lienzo para editarla"
		btn_edit.pressed.connect(func(): controlador.cargar_subrutina_en_lienzo(op_id))
		fila.add_child(btn_edit)
		
		var btn_del := Button.new()
		btn_del.text = "X"
		btn_del.tooltip_text = "Eliminar subrutina"
		btn_del.pressed.connect(func(): controlador.eliminar_subrutina_guardada(op_id))
		fila.add_child(btn_del)
		contenedor_subrutinas_guardadas.add_child(fila)

func _on_compilacion_exitosa(ruta: String) -> void:
	if label_estado_compilacion:
		label_estado_compilacion.text = "✅ Guardado en:\n" + ruta

func _centrar_camara() -> void:
	if scroll_container:
		scroll_container.scroll_horizontal = 2000 - int(scroll_container.size.x / 2)
		scroll_container.scroll_vertical = 0

func _on_boton_agregar_pressed() -> void:
	controlador.id_nodo_en_mutacion = -1
	
	var evento_id : int = _buscar_evento_raiz()
	if evento_id != -1:
		var destino : Dictionary = controlador._encontrar_cola_de_insercion(evento_id, &"id_siguiente_ejecución")
		controlador.id_padre_pendiente = destino["id"]
		controlador.puerto_pendiente = destino["puerto"]
	
	var definiciones : Array = controlador.obtener_definiciones_validas()
	_abrir_menu_flotante_con_datos(definiciones)

func _abrir_menu_flotante_con_datos(definiciones: Array) -> void:
	menu_bloques.cargar_opciones(definiciones)
	var rect = get_viewport_rect()
	menu_bloques.popup(Rect2i(int(rect.size.x / 2) - 125, int(rect.size.y / 2) - 150, 250, 300))

func _on_instruccion_seleccionada_en_menu(operacion_host: StringName) -> void:
	if controlador.id_nodo_en_mutacion != -1:
		controlador.ejecutar_mutacion(operacion_host)
	else:
		controlador.agregar_bloque(operacion_host)
		contenedor_bloques.move_child(boton_agregar, -1)

func _buscar_evento_raiz() -> int:
	var ev := controlador.programa_de_usuario.obtener_nodo_evento_raiz()
	return ev.id if ev else -1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): 
		controlador.compilar()
		
	if event.is_action_pressed("ui_undo"):
		controlador.historial.undo()
	elif event.is_action_pressed("ui_redo"):
		controlador.historial.redo()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				haciendo_paneo = true
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				haciendo_paneo = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if event is InputEventMouseMotion and haciendo_paneo:
		if scroll_container:
			scroll_container.scroll_horizontal -= int(event.relative.x)
			scroll_container.scroll_vertical -= int(event.relative.y)
