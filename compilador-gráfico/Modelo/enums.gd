extends Resource
class_name GabyEnums

enum CategoriaNodo {EVENTO, ACCIÓN, CONTROL, EXPRESION}
enum TipoDato {INT = 0, FLOAT = 1, STRING = 2, BOOLEAN = 3, PRODUCTO = 4, ARRAY = 5, ANY = 6}

# Registro dinámico de tipos para soportar nuevos Objetos del Dominio sin recompilar
static var _nombres_a_id : Dictionary = {
	"INT": TipoDato.INT,
	"FLOAT": TipoDato.FLOAT,
	"STRING": TipoDato.STRING,
	"BOOLEAN": TipoDato.BOOLEAN,
	"PRODUCTO": TipoDato.PRODUCTO,
	"ARRAY": TipoDato.ARRAY,
	"ANY": TipoDato.ANY
}

static var _id_a_etiqueta : Dictionary = {
	TipoDato.INT: "Entero (INT)",
	TipoDato.FLOAT: "Decimal (FLOAT)",
	TipoDato.STRING: "Texto (STRING)",
	TipoDato.BOOLEAN: "Booleano (BOOL)",
	TipoDato.PRODUCTO: "Objeto: PRODUCTO",
	TipoDato.ARRAY: "Arreglo (ARRAY)",
	TipoDato.ANY: "Cualquiera (ANY)"
}

static var _proximo_id_objeto : int = 10

static func registrar_tipo_objeto(nombre_objeto: String) -> int:
	var clave := nombre_objeto.strip_edges().to_upper()
	if _nombres_a_id.has(clave):
		return _nombres_a_id[clave]
	var nuevo_id : int = _proximo_id_objeto
	_proximo_id_objeto += 1
	_nombres_a_id[clave] = nuevo_id
	_id_a_etiqueta[nuevo_id] = "Objeto: " + clave
	return nuevo_id

static func obtener_id_tipo(nombre: String) -> int:
	var clave := nombre.strip_edges().to_upper()
	if _nombres_a_id.has(clave):
		return _nombres_a_id[clave]
	return registrar_tipo_objeto(clave)

static func obtener_nombre_codigo(id_tipo: int) -> String:
	for k in _nombres_a_id.keys():
		if _nombres_a_id[k] == id_tipo:
			return k
	return "ANY"

static func obtener_etiqueta(id_tipo: int) -> String:
	return _id_a_etiqueta.get(id_tipo, "Objeto #" + str(id_tipo))

static func obtener_diccionario_etiquetas() -> Dictionary:
	return _id_a_etiqueta

static func son_compatibles(tipo_origen: int, tipo_destino: int) -> bool:
	if tipo_destino == TipoDato.ANY or tipo_origen == TipoDato.ANY:
		return true
	# Permitir que INT se conecte donde se espera FLOAT (promoción numérica)
	if tipo_destino == TipoDato.FLOAT and tipo_origen == TipoDato.INT:
		return true
	return tipo_origen == tipo_destino
