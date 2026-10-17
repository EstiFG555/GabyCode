extends Control

var controlador: GestorEditor

@export var contenedor_bloques: VBoxContainer
@export var boton_agregar: Button
@export var menu_bloques: MenuBloquesUI
@export var scroll_container: ScrollContainer 
@export var modal_expresion: ModalExpresionUI
var haciendo_paneo: bool = false


func _ready() -> void:
	# 1. Inicializamos el Cerebro (Controlador)
	controlador = GestorEditor.new()
	add_child(controlador) 
	
	# 2. Le pasamos al controlador el contenedor donde debe dibujar los bloques
	controlador.contenedor_flujo_ui = contenedor_bloques
	
	# 3. Conectamos los botones de la UI
	boton_agregar.pressed.connect(_on_boton_agregar_pressed)
	menu_bloques.instruccion_seleccionada.connect(_on_instruccion_seleccionada_en_menu)
	
	# --- 4. TRUCO DEL LIENZO INFINITO ---
	# Forzamos un tamaño gigante para que el ScrollContainer siempre permita panear
	contenedor_bloques.custom_minimum_size = Vector2(4000, 4000)
	
	# Esperamos un frame a que Godot procese las UI y centramos la vista
	call_deferred("_centrar_camara")

func _centrar_camara() -> void:
	if scroll_container:
		# Centramos horizontalmente y dejamos un margen arriba
		scroll_container.scroll_horizontal = 2000 - int(scroll_container.size.x / 2)
		scroll_container.scroll_vertical = 0

func _on_boton_agregar_pressed() -> void:
	# Reseteamos mutación por si acaso
	controlador.id_nodo_en_mutacion = -1
	
	# --- FIX DE ENRUTAMIENTO ---
	# Forzamos al botón global a buscar el final de la secuencia principal
	var evento_id : int = _buscar_evento_raiz()
	if evento_id != -1:
		var destino : Dictionary = controlador._encontrar_cola_de_insercion(evento_id, &"id_siguiente_ejecución")
		controlador.id_padre_pendiente = destino["id"]
		controlador.puerto_pendiente = destino["puerto"]
	# ---------------------------
	
	var definiciones : Array = controlador.obtener_definiciones_validas()
	_abrir_menu_flotante_con_datos(definiciones)

func _abrir_menu_flotante_con_datos(definiciones: Array) -> void:
	menu_bloques.cargar_opciones(definiciones)
	var rect = get_viewport_rect()
	menu_bloques.popup(Rect2i(rect.size.x / 2 - 125, rect.size.y / 2 - 150, 250, 300))

func _on_instruccion_seleccionada_en_menu(operacion_host: StringName) -> void:
	# Si estábamos mutando, ejecutamos mutación. Si no, agregamos.
	if controlador.id_nodo_en_mutacion != -1:
		controlador.ejecutar_mutacion(operacion_host)
	else:
		controlador.agregar_bloque(operacion_host)
		contenedor_bloques.move_child(boton_agregar, -1)

func _buscar_evento_raiz() -> int:
	for id in controlador.programa_de_usuario.nodos_grafos.keys():
		if controlador.programa_de_usuario.nodos_grafos[id].categoria == GabyEnums.CategoriaNodo.EVENTO:
			return id
	return -1

# Atajo de teclado para probar la compilación al final
# Atajos de teclado del editor
func _input(event: InputEvent) -> void:
	# --- ATAJOS DE TECLADO ---
	if event.is_action_pressed("ui_accept"): 
		controlador.compilar()
		
	if event.is_action_pressed("ui_undo"):
		controlador.historial.undo()
	elif event.is_action_pressed("ui_redo"):
		controlador.historial.redo()

	# --- LÓGICA DE PANEO (Miro / Zapier) ---
	if event is InputEventMouseButton:
		# Usamos el Botón Derecho o el Botón Medio para arrastrar
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				haciendo_paneo = true
				Input.set_default_cursor_shape(Input.CURSOR_DRAG) # Cambia el cursor a la "manito"
			else:
				haciendo_paneo = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if event is InputEventMouseMotion and haciendo_paneo:
		if scroll_container:
			# Desplazamos las barras de scroll basándonos en cuánto se movió el ratón
			scroll_container.scroll_horizontal -= int(event.relative.x)
			scroll_container.scroll_vertical -= int(event.relative.y)
