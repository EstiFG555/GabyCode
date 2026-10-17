extends PopupPanel
class_name ModalExpresionUI

signal formula_configurada(operacion_host: StringName, parametros_ingresados: Dictionary)

@export var titulo_label: Label
@export var selector_operacion: OptionButton
@export var contenedor_parametros: VBoxContainer
@export var boton_cancelar: Button
@export var boton_inyectar: Button

var func_busqueda: Callable
var id_nodo_destino: int
var definiciones_validas: Array = []

func _ready() -> void:
	boton_cancelar.pressed.connect(func(): self.hide())
	boton_inyectar.pressed.connect(_on_boton_inyectar_presionado)
	selector_operacion.item_selected.connect(_on_operacion_seleccionada)

func abrir_modal(id_destino: int, nombre_parametro: String, tipo_requerido: GabyEnums.TipoDato, defs_todas: Dictionary, funcion_buscar: Callable) -> void:
	id_nodo_destino = id_destino
	func_busqueda = funcion_buscar
	definiciones_validas.clear()
	selector_operacion.clear()
	
	if titulo_label:
		titulo_label.text = "Fórmula para: " + nombre_parametro.capitalize()
		
	for key in defs_todas.keys():
		var def : DefinicionBloque = defs_todas[key]
		if def.categoria == GabyEnums.CategoriaNodo.EXPRESION:
			var tipo_salida = def.tipos_salidas_provistas.get(&"resultado", GabyEnums.TipoDato.ANY)
			if tipo_salida == tipo_requerido or tipo_requerido == GabyEnums.TipoDato.ANY:
				definiciones_validas.append(def)
				selector_operacion.add_item(def.nombre_visual)
				selector_operacion.set_item_metadata(selector_operacion.item_count - 1, def)
				
	if definiciones_validas.is_empty():
		push_warning("No hay fórmulas disponibles para el tipo requerido.")
		return
		
	_on_operacion_seleccionada(0)
	popup_centered(Vector2i(350, 250))

func _on_operacion_seleccionada(index: int) -> void:
	for hijo in contenedor_parametros.get_children(): hijo.queue_free()
		
	var definicion : DefinicionBloque = selector_operacion.get_item_metadata(index)
	if not definicion: return
	
	for nombre_param in definicion.tipos_entradas_esperadas.keys():
		var tipo_req = definicion.tipos_entradas_esperadas[nombre_param]
		
		var fila = HBoxContainer.new()
		var label = Label.new()
		label.text = str(nombre_param).capitalize() + ":"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)
		
		var option_btn = OptionButton.new()
		option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_btn.add_item("Conectar...")
		option_btn.set_item_metadata(0, null)
		
		var literal_input = LineEdit.new()
		literal_input.placeholder_text = "Literal..."
		literal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var opciones = func_busqueda.call(id_nodo_destino, nombre_param, tipo_req)
		var idx = 1
		for opc in opciones:
			if opc["datos_conexion"].get("fuente") == "CREAR_EXPRESION": continue # Evitar inception de fórmulas
			option_btn.add_item(opc["texto_mostrar"])
			option_btn.set_item_metadata(idx, opc["datos_conexion"])
			idx += 1
			
		fila.add_child(option_btn)
		fila.add_child(literal_input)
		contenedor_parametros.add_child(fila)

func _on_boton_inyectar_presionado() -> void:
	var definicion : DefinicionBloque = selector_operacion.get_item_metadata(selector_operacion.selected)
	var parametros_recolectados : Dictionary = {}
	
	var i = 0
	for nombre_param in definicion.tipos_entradas_esperadas.keys():
		var tipo_req = definicion.tipos_entradas_esperadas[nombre_param]
		var fila = contenedor_parametros.get_child(i)
		var option_btn : OptionButton = fila.get_child(1)
		var literal_input : LineEdit = fila.get_child(2)
		
		if option_btn.selected > 0:
			parametros_recolectados[nombre_param] = option_btn.get_item_metadata(option_btn.selected)
		elif literal_input.text.strip_edges() != "":
			var valor_casteado = _castear_literal(literal_input.text, tipo_req)
			parametros_recolectados[nombre_param] = {"fuente": "LITERAL", "valor": valor_casteado}
			
		i += 1
		
	formula_configurada.emit(definicion.operacion_host, parametros_recolectados)
	self.hide()

func _castear_literal(texto: String, tipo_esperado: GabyEnums.TipoDato) -> Variant:
	var txt = texto.strip_edges()
	if txt == "": return null
	match tipo_esperado:
		GabyEnums.TipoDato.INT: return txt.to_int()
		GabyEnums.TipoDato.FLOAT: return txt.to_float()
		GabyEnums.TipoDato.BOOLEAN: return txt.to_lower() == "true" or txt == "1"
		_: return txt
