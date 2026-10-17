extends PanelContainer
class_name BloqueBaseUI

signal solicitar_eliminacion(id_nodo : int)
signal solicitar_mutacion(id_nodo : int)
signal parametro_modificado(id_nodo : int, nombre_parametro : StringName, nuevo_valor : Variant)
signal solicitar_creacion_expresion(id_nodo: int, nombre_parametro: StringName, tipo_esperado: int)

var id_logico : int = 0
@export var label_titulo : Label
@export var boton_eliminar : Button
@export var boton_modificar : Button


func inicializar(id_asignado : int, titulo : String, entradas_esperadas : Dictionary, funcion_buscar_opciones : Callable, estado_guardado : Dictionary = {}) -> void:
	id_logico = id_asignado
	
	if label_titulo:
		label_titulo.text = titulo
		
	# Conectamos el botón de borrar de forma segura
	if boton_eliminar and not boton_eliminar.pressed.is_connected(_on_boton_eliminar_presionado):
		boton_eliminar.pressed.connect(_on_boton_eliminar_presionado)
	
	if boton_modificar and not boton_modificar.pressed.is_connected(_on_boton_modificar_presionado):
		boton_modificar.pressed.connect(_on_boton_modificar_presionado)

func _on_boton_eliminar_presionado() -> void:
	solicitar_eliminacion.emit(id_logico)

func _on_boton_modificar_presionado() -> void:
	solicitar_mutacion.emit(id_logico)
