extends PopupPanel
class_name MenuBloquesUI

signal instruccion_seleccionada(operacion_host: StringName)

@export var contenedor_lista: VBoxContainer

func cargar_opciones(definiciones_validas: Array) -> void:
	# 1. Limpiar opciones anteriores
	for hijo in contenedor_lista.get_children():
		hijo.queue_free()
		
	# 2. Generar un botón por cada bloque válido
	for def: DefinicionBloque in definiciones_validas:
		var btn := Button.new()
		btn.text = def.nombre_visual
		btn.custom_minimum_size = Vector2(0, 40) # Botones altos y fáciles de clickear
		
		# Conectamos el clic del botón a una función anónima (Lambda)
		btn.pressed.connect(func():
			instruccion_seleccionada.emit(def.operacion_host)
			self.hide() # Ocultamos el popup tras seleccionar
		)
		
		contenedor_lista.add_child(btn)
