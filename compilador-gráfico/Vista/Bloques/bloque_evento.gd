extends BloqueBaseUI
class_name BloqueEventoUI

signal solicitar_eliminar_parametro_subrutina(nombre_parametro: String)

var contenedor_salidas : VBoxContainer = null

func inicializar(id_asignado : int, titulo : String, entradas_esperadas : Dictionary, funcion_buscar_opciones : Callable, estado_guardado : Dictionary = {}) -> void:
	super.inicializar(id_asignado, titulo, entradas_esperadas, funcion_buscar_opciones, estado_guardado)
	
	if boton_eliminar:
		boton_eliminar.hide()

func mostrar_salidas_contexto(
		salidas_provistas: Dictionary,
		subtipos_array: Dictionary,
		es_subrutina_entry: bool = false,
		tipo_retorno_sub: int = -1,
		subtipo_retorno_sub: int = GabyEnums.TipoDato.ANY
) -> void:
	var cont_principal := get_node_or_null("ContenedorPrincipal") as VBoxContainer
	if not cont_principal:
		return
		
	if not contenedor_salidas:
		contenedor_salidas = VBoxContainer.new()
		contenedor_salidas.name = "ContenedorSalidasContexto"
		cont_principal.add_child(contenedor_salidas)
		
	for hijo in contenedor_salidas.get_children():
		hijo.queue_free()
		
	contenedor_salidas.add_child(HSeparator.new())
	
	var lbl_header := Label.new()
	lbl_header.text = "📥 Parámetros de Entrada:" if es_subrutina_entry else "📤 Datos provistos al contexto:"
	lbl_header.add_theme_font_size_override("font_size", 12)
	contenedor_salidas.add_child(lbl_header)
	
	if salidas_provistas.is_empty():
		var lbl_vacio := Label.new()
		lbl_vacio.text = "  (Sin parámetros de entrada)" if es_subrutina_entry else "  (Sin datos de contexto)"
		lbl_vacio.add_theme_font_size_override("font_size", 11)
		contenedor_salidas.add_child(lbl_vacio)
	else:
		for nombre_puerto in salidas_provistas.keys():
			var fila := HBoxContainer.new()
			var tipo_id : int = salidas_provistas[nombre_puerto]
			var desc_tipo := GabyEnums.obtener_nombre_codigo(tipo_id)
			if tipo_id == GabyEnums.TipoDato.ARRAY and subtipos_array.has(nombre_puerto):
				desc_tipo += "<" + GabyEnums.obtener_nombre_codigo(subtipos_array[nombre_puerto]) + ">"
				
			var lbl_puerto := Label.new()
			lbl_puerto.text = " • %s  [%s]" % [String(nombre_puerto), desc_tipo]
			lbl_puerto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(lbl_puerto)
			
			if es_subrutina_entry:
				var btn_quitar := Button.new()
				btn_quitar.text = "x"
				btn_quitar.tooltip_text = "Quitar parámetro de subrutina"
				btn_quitar.pressed.connect(func():
					solicitar_eliminar_parametro_subrutina.emit(String(nombre_puerto))
				)
				fila.add_child(btn_quitar)
				
			contenedor_salidas.add_child(fila)
			
	if es_subrutina_entry:
		contenedor_salidas.add_child(HSeparator.new())
		var lbl_ret := Label.new()
		lbl_ret.add_theme_font_size_override("font_size", 12)
		if tipo_retorno_sub == -1:
			lbl_ret.text = "📤 Retorno: Sin Retorno (Void)"
		else:
			var desc_ret := GabyEnums.obtener_nombre_codigo(tipo_retorno_sub)
			if tipo_retorno_sub == GabyEnums.TipoDato.ARRAY:
				desc_ret += "<" + GabyEnums.obtener_nombre_codigo(subtipo_retorno_sub) + ">"
			lbl_ret.text = "📤 Retorno: resultado [%s] (Usa bloque RETURN)" % desc_ret
		contenedor_salidas.add_child(lbl_ret)
