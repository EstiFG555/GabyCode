extends BloqueBaseUI
class_name BloqueEventoUI

func inicializar(id_asignado : int, titulo : String, entradas_esperadas : Dictionary, funcion_buscar_opciones : Callable, estado_guardado : Dictionary = {}) -> void:
	super.inicializar(id_asignado, titulo, entradas_esperadas, funcion_buscar_opciones, estado_guardado)
	
	# 2. Bloqueo de UX: Los eventos son la raíz, no se pueden borrar, solo mutar.
	if boton_eliminar:
		boton_eliminar.hide()
