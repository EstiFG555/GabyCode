extends RefCounted
class_name BloqueFactory

const TIPOS_BLOQUES : Dictionary[GabyEnums.CategoriaNodo, StringName] = {
	GabyEnums.CategoriaNodo.EVENTO : &"res://Vista/Bloques/bloque_evento.tscn",
	GabyEnums.CategoriaNodo.ACCIÓN : &"res://Vista/Bloques/bloque_acción.tscn",
	GabyEnums.CategoriaNodo.CONTROL: &"res://Vista/Bloques/bloque_control.tscn"
}


func construir_bloque_logico(tipo : GabyEnums.CategoriaNodo) -> NodoBaseASG:
	var bloque : NodoBaseASG = null
	match tipo:
		GabyEnums.CategoriaNodo.EVENTO:
			bloque = ASGEvento.new()
		GabyEnums.CategoriaNodo.ACCIÓN:
			bloque = ASGAcción.new()
		GabyEnums.CategoriaNodo.CONTROL:
			bloque = ASGControl.new()
	
	return bloque

func construir_bloque_ui(tipo : GabyEnums.CategoriaNodo) -> BloqueBaseUI:
	var bloque : BloqueBaseUI = null
	
	match tipo:
		GabyEnums.CategoriaNodo.EVENTO:
			bloque = load(TIPOS_BLOQUES[tipo]).instantiate() as BloqueEventoUI
		GabyEnums.CategoriaNodo.ACCIÓN:
			bloque = load(TIPOS_BLOQUES[tipo]).instantiate() as BloqueAccionUI
		GabyEnums.CategoriaNodo.CONTROL:
			bloque = load(TIPOS_BLOQUES[tipo]).instantiate() as BloqueControlUI
	
	return bloque
