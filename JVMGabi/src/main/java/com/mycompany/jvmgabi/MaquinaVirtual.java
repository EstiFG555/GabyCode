/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.jvmgabi;

/**
 *
 * @author Agustina
 */
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Stack;
import java.util.function.Consumer;

public class MaquinaVirtual {

    // Excepción controlada para reportar errores semánticos o de dominio en tiempo de ejecución
    public static class ExcepcionEjecucionVM extends RuntimeException {
        public ExcepcionEjecucionVM(String mensaje) {
            super(mensaje);
        }
    }

    @FunctionalInterface
    public interface FuncionHost {
        Object ejecutar(List<Object> parametros) throws ExcepcionEjecucionVM;
    }

    public static class Producto {
        public int id;
        public String nombre;
        public double precio;
        public int stock;

        public Producto(int id, String nombre, double precio, int stock) {
            this.id = id;
            this.nombre = nombre;
            this.precio = precio;
            this.stock = stock;
        }

        @Override
        public String toString() {
            return String.format("Producto[#%d %s | $%.2f | Stock:%d]", id, nombre, precio, stock);
        }
    }

    private final Stack<Object> pila;
    private final Stack<Map<String, Object>> pilaScopes;
    private final Stack<Integer> pilaRetorno;
    private final Map<String, Object> memoriaEventos;
    private final Map<Integer, Producto> catalogoProductos;
    private final Map<String, FuncionHost> registroFuncionesHost;
    private Consumer<String> loggerCallback;

    public MaquinaVirtual() {
        this.pila = new Stack<>();
        this.pilaScopes = new Stack<>();
        this.pilaRetorno = new Stack<>();
        this.memoriaEventos = new HashMap<>();
        this.catalogoProductos = new LinkedHashMap<>();
        this.registroFuncionesHost = new HashMap<>();
        inicializarInventarioPorDefecto();
        registrarFuncionesHostNativas();
    }

    public void setLoggerCallback(Consumer<String> callback) {
        this.loggerCallback = callback;
    }

    private void log(String mensaje) {
        System.out.println(mensaje);
        if (loggerCallback != null) {
            loggerCallback.accept(mensaje);
        }
    }

    public final void inicializarInventarioPorDefecto() {
        catalogoProductos.clear();
        catalogoProductos.put(101, new Producto(101, "Leche Entera 1L", 1200.0, 3));
        catalogoProductos.put(102, new Producto(102, "Pan Dulce Navideño", 4500.0, 12));
        catalogoProductos.put(103, new Producto(103, "Arroz Grano Largo 1Kg", 1500.0, 20));
        catalogoProductos.put(104, new Producto(104, "Sidra Etiqueta Blanca", 3200.0, 8));

        inyectarDatoEvento("ProductoActual", catalogoProductos.get(101));
        inyectarDatoEvento("producto_leido", catalogoProductos.get(101));
        inyectarDatoEvento("lista_productos", new ArrayList<>(Arrays.asList(
                catalogoProductos.get(101),
                catalogoProductos.get(103)
        )));
        inyectarDatoEvento("lista_ids_descuento", new ArrayList<>(Arrays.asList(102, 104)));
    }

    public final void registrarFuncionHost(String nombreOperacion, FuncionHost manejador) {
        registroFuncionesHost.put(nombreOperacion.toUpperCase(), manejador);
    }

    private void registrarFuncionesHostNativas() {
        // Funciones básicas de compatibilidad
        registrarFuncionHost("SUMAR", params -> aEntero(params.get(0)) + aEntero(params.get(1)));
        registrarFuncionHost("MULTIPLICAR", params -> aEntero(params.get(0)) * aEntero(params.get(1)));
        registrarFuncionHost("MOSTRAR", params -> {
            log(" 💬 [MOSTRAR] " + params.get(0));
            return 0;
        });

        // Funciones del dominio de la Despensa con validación estricta de errores
        registrarFuncionHost("GET_STOCK", params -> {
            Producto prod = exigirProductoValido("GET_STOCK", params.get(0));
            log(" 📦 [GET_STOCK] Stock de '" + prod.nombre + "' (ID #" + prod.id + ") = " + prod.stock + " unidades.");
            return prod.stock;
        });

        registrarFuncionHost("GET_PRODUCT_BY_ID", params -> {
            if (params.isEmpty() || params.get(0) == null) {
                throw new ExcepcionEjecucionVM("GET_PRODUCT_BY_ID: Se recibió un ID nulo.");
            }
            int idProd = aEnteroEstricto("GET_PRODUCT_BY_ID", params.get(0));
            Producto prod = catalogoProductos.get(idProd);
            if (prod == null) {
                throw new ExcepcionEjecucionVM("GET_PRODUCT_BY_ID: El producto con ID #" + idProd + " no existe en el inventario de la despensa.");
            }
            log(" 🔍 [GET_PRODUCT_BY_ID] ID #" + idProd + " encontrado -> " + prod.nombre + " ($" + prod.precio + ")");
            return prod;
        });

        registrarFuncionHost("APPLY_DISCOUNT", params -> {
            Producto prod = exigirProductoValido("APPLY_DISCOUNT", params.get(0));
            double porcentaje = aNumeroEstricto("APPLY_DISCOUNT", params.get(1));
            if (porcentaje < 0.0 || porcentaje > 100.0) {
                throw new ExcepcionEjecucionVM("APPLY_DISCOUNT: Porcentaje de descuento inválido (" + porcentaje + "%). Debe estar entre 0% y 100%.");
            }
            double precioAnterior = prod.precio;
            prod.precio = Math.round((prod.precio * (1.0 - porcentaje / 100.0)) * 100.0) / 100.0;
            log(String.format(" 🏷️ [APPLY_DISCOUNT] %.1f%% de descuento en '%s' ($%.2f -> $%.2f)",
                    porcentaje, prod.nombre, precioAnterior, prod.precio));
            return 0;
        });

        registrarFuncionHost("SHOW_ALERT", params -> {
            String msg = (params.isEmpty() || params.get(0) == null) ? "" : String.valueOf(params.get(0));
            log(" 🚨 [SHOW_ALERT] " + msg);
            return 0;
        });

        registrarFuncionHost("CALCULATE_SALE_TOTAL", params -> {
            List<Object> lista = convertirALista(params.get(0));
            if (lista.isEmpty()) {
                throw new ExcepcionEjecucionVM("CALCULATE_SALE_TOTAL: La lista de productos de la venta está vacía.");
            }
            double total = 0.0;
            for (Object item : lista) {
                Producto p = exigirProductoValido("CALCULATE_SALE_TOTAL", item);
                total += p.precio;
            }
            log(String.format(" 🧮 [CALCULATE_SALE_TOTAL] Total calculado para %d productos = $%.2f", lista.size(), total));
            return total;
        });

        registrarFuncionHost("REGISTER_SALE", params -> {
            List<Object> lista = convertirALista(params.get(0));
            double total = aNumeroEstricto("REGISTER_SALE", params.get(1));
            if (lista.isEmpty()) {
                throw new ExcepcionEjecucionVM("REGISTER_SALE: No se puede registrar una venta sin productos.");
            }
            for (Object item : lista) {
                Producto p = exigirProductoValido("REGISTER_SALE", item);
                if (p.stock <= 0) {
                    throw new ExcepcionEjecucionVM("REGISTER_SALE: Stock agotado para el producto '" + p.nombre + "' (ID #" + p.id + ").");
                }
                p.stock -= 1;
            }
            log(String.format(" 🧾 [REGISTER_SALE] Venta registrada (%d ítems) por $%.2f. Stock descontado.",
                    lista.size(), total));
            return 0;
        });

        registrarFuncionHost("SHOW_TOTAL", params -> {
            double total = aNumeroEstricto("SHOW_TOTAL", params.get(0));
            log(String.format(" 💰 [SHOW_TOTAL] TOTAL A PAGAR EN CAJA: $%.2f", total));
            return 0;
        });

        // Primitivas de iteración polimórfica ForEach
        registrarFuncionHost("HAS_NEXT", params -> {
            int idx = aEntero(params.get(0));
            List<Object> lista = convertirALista(params.get(1));
            return (idx >= 0 && idx < lista.size()) ? 1 : 0;
        });

        registrarFuncionHost("GET_ITEM", params -> {
            int idx = aEntero(params.get(0));
            List<Object> lista = convertirALista(params.get(1));
            if (idx < 0 || idx >= lista.size()) {
                throw new ExcepcionEjecucionVM("GET_ITEM: Índice fuera de rango (" + idx + ") para una lista de tamaño " + lista.size());
            }
            return lista.get(idx);
        });
    }

    public Map<Integer, Producto> getCatalogoProductos() {
        return catalogoProductos;
    }

    public Map<String, Object> getMemoriaEventos() {
        return memoriaEventos;
    }

    public void inyectarDatoEvento(String clave, Object valor) {
        memoriaEventos.put(clave, valor);
    }

    public boolean ejecutar(List<String> programa) {
        pila.clear();
        pilaScopes.clear();
        pilaRetorno.clear();
        pilaScopes.push(new HashMap<>());

        int pc = 0;
        String lineaActual = "";
        try {
            while (pc < programa.size()) {
                lineaActual = programa.get(pc).trim();

                if (lineaActual.isEmpty() || lineaActual.startsWith("#") || lineaActual.startsWith("//")) {
                    pc++;
                    continue;
                }

                String[] partes = lineaActual.split("\\s+", 2);
                String instruccion = partes[0].toUpperCase();
                String operandoCrudo = partes.length > 1 ? partes[1].trim() : "";

                switch (instruccion) {
                    case "PUSH", "PUSH_LITERAL" -> pila.push(parsearLiteral(operandoCrudo));

                    case "POP" -> {
                        if (!pila.isEmpty()) pila.pop();
                    }

                    case "STORE", "STORE_VAR" -> {
                        if (pila.isEmpty()) {
                            throw new ExcepcionEjecucionVM("STORE: Pila vacía al intentar guardar en variable '" + operandoCrudo + "'.");
                        }
                        Object valor = pila.pop();
                        if (pilaScopes.size() == 1 && memoriaEventos.containsKey(operandoCrudo)
                                && Integer.valueOf(0).equals(valor)) {
                            pilaScopes.peek().put(operandoCrudo, memoriaEventos.get(operandoCrudo));
                        } else {
                            pilaScopes.peek().put(operandoCrudo, valor);
                        }
                    }

                    case "LOAD", "LOAD_VAR" -> {
                        Map<String, Object> scopeLocal = pilaScopes.peek();
                        Object valor;
                        if (scopeLocal.containsKey(operandoCrudo)) {
                            valor = scopeLocal.get(operandoCrudo);
                        } else if (memoriaEventos.containsKey(operandoCrudo)) {
                            valor = memoriaEventos.get(operandoCrudo);
                        } else {
                            throw new ExcepcionEjecucionVM("LOAD: La variable o dato de contexto '" + operandoCrudo + "' no fue inicializado.");
                        }
                        pila.push(valor);
                    }

                    case "CALL" -> {
                        int direccionSubrutina = Integer.parseInt(operandoCrudo);
                        pilaRetorno.push(pc + 1);
                        pilaScopes.push(new HashMap<>());
                        log(" 🔄 [VM CALL] Entrando a Subrutina en línea " + direccionSubrutina + " (Nuevo Scope aislado)");
                        pc = direccionSubrutina;
                        continue;
                    }

                    case "RET" -> {
                        if (!pilaScopes.isEmpty()) pilaScopes.pop();
                        if (pilaRetorno.isEmpty()) return true;
                        pc = pilaRetorno.pop();
                        log(" ↩️ [VM RET] Retornando de Subrutina a línea " + pc);
                        continue;
                    }

                    case "ADD", "OP_ADD" -> {
                        exigirOperandosEnPila("ADD", 2);
                        Object b = pila.pop();
                        Object a = pila.pop();
                        if (a instanceof String || b instanceof String) {
                            pila.push(String.valueOf(a) + String.valueOf(b));
                        } else if (a instanceof Double || b instanceof Double) {
                            pila.push(aNumeroEstricto("ADD", a) + aNumeroEstricto("ADD", b));
                        } else {
                            pila.push(aEnteroEstricto("ADD", a) + aEnteroEstricto("ADD", b));
                        }
                    }

                    case "SUB", "OP_SUB" -> {
                        exigirOperandosEnPila("SUB", 2);
                        Object b = pila.pop();
                        Object a = pila.pop();
                        if (a instanceof Double || b instanceof Double) {
                            pila.push(aNumeroEstricto("SUB", a) - aNumeroEstricto("SUB", b));
                        } else {
                            pila.push(aEnteroEstricto("SUB", a) - aEnteroEstricto("SUB", b));
                        }
                    }

                    case "MUL", "OP_MUL" -> {
                        exigirOperandosEnPila("MUL", 2);
                        Object b = pila.pop();
                        Object a = pila.pop();
                        if (a instanceof Double || b instanceof Double) {
                            pila.push(aNumeroEstricto("MUL", a) * aNumeroEstricto("MUL", b));
                        } else {
                            pila.push(aEnteroEstricto("MUL", a) * aEnteroEstricto("MUL", b));
                        }
                    }

                    case "DIV", "OP_DIV" -> {
                        exigirOperandosEnPila("DIV", 2);
                        Object b = pila.pop();
                        Object a = pila.pop();
                        double divisor = aNumeroEstricto("DIV", b);
                        if (divisor == 0.0) {
                            throw new ExcepcionEjecucionVM("DIV: División matemática por cero.");
                        }
                        if (a instanceof Double || b instanceof Double) {
                            pila.push(aNumeroEstricto("DIV", a) / divisor);
                        } else {
                            pila.push(aEnteroEstricto("DIV", a) / aEnteroEstricto("DIV", b));
                        }
                    }

                    case "AND", "OP_AND" -> {
                        exigirOperandosEnPila("AND", 2);
                        boolean b = aBooleano(pila.pop());
                        boolean a = aBooleano(pila.pop());
                        pila.push((a && b) ? 1 : 0);
                    }

                    case "OR", "OP_OR" -> {
                        exigirOperandosEnPila("OR", 2);
                        boolean b = aBooleano(pila.pop());
                        boolean a = aBooleano(pila.pop());
                        pila.push((a || b) ? 1 : 0);
                    }

                    case "EQ", "OP_CMP_EQ" -> {
                        exigirOperandosEnPila("EQ", 2);
                        Object b = pila.pop();
                        Object a = pila.pop();
                        pila.push(sonIguales(a, b) ? 1 : 0);
                    }

                    case "GT", "OP_CMP_GT" -> {
                        exigirOperandosEnPila("GT", 2);
                        double b = aNumeroEstricto("GT", pila.pop());
                        double a = aNumeroEstricto("GT", pila.pop());
                        pila.push(a > b ? 1 : 0);
                    }

                    case "LT", "OP_CMP_LT" -> {
                        exigirOperandosEnPila("LT", 2);
                        double b = aNumeroEstricto("LT", pila.pop());
                        double a = aNumeroEstricto("LT", pila.pop());
                        pila.push(a < b ? 1 : 0);
                    }

                    case "PRINT" -> {
                        exigirOperandosEnPila("PRINT", 1);
                        log(" 🖨️ [PRINT] " + pila.pop());
                    }

                    case "JMP", "JUMP" -> {
                        pc = Integer.parseInt(operandoCrudo);
                        continue;
                    }

                    case "JMP_IF_TRUE" -> {
                        exigirOperandosEnPila("JMP_IF_TRUE", 1);
                        if (aBooleano(pila.pop())) {
                            pc = Integer.parseInt(operandoCrudo);
                            continue;
                        }
                    }

                    case "JMP_IF_FALSE", "JUMP_IF_FALSE" -> {
                        exigirOperandosEnPila("JMP_IF_FALSE", 1);
                        if (!aBooleano(pila.pop())) {
                            pc = Integer.parseInt(operandoCrudo);
                            continue;
                        }
                    }

                    case "CALL_HOST" -> {
                        String[] argsHost = operandoCrudo.split("\\s+");
                        String nombreFuncion = argsHost[0].toUpperCase();
                        int aridad = (argsHost.length > 1) ? Integer.parseInt(argsHost[1]) : inferirAridadPorDefecto(nombreFuncion);

                        exigirOperandosEnPila("CALL_HOST " + nombreFuncion, aridad);
                        List<Object> parametros = new ArrayList<>();
                        for (int i = 0; i < aridad; i++) {
                            parametros.add(0, pila.pop());
                        }

                        FuncionHost funcion = registroFuncionesHost.get(nombreFuncion);
                        if (funcion == null) {
                            throw new ExcepcionEjecucionVM("CALL_HOST: La función nativa '" + nombreFuncion + "' no está registrada en la Máquina Virtual.");
                        }
                        Object resultado = funcion.ejecutar(parametros);
                        pila.push(resultado);
                    }

                    case "HALT" -> {
                        log(" ✅ [VM HALT] Ejecución finalizada sin errores. Scope Principal: " + pilaScopes.peek());
                        return true;
                    }

                    default -> throw new ExcepcionEjecucionVM("Instrucción Bytecode desconocida: '" + instruccion + "'.");
                }
                pc++;
            }
            return true;
        } catch (ExcepcionEjecucionVM ex) {
            log(String.format(" ❌ [ERROR DE EJECUCIÓN VM en línea #%d (%s)]: %s", pc, lineaActual, ex.getMessage()));
            log(" ⛔ Ejecución abortada de forma segura por la Máquina Virtual.");
            return false;
        } catch (Exception ex) {
            log(String.format(" ❌ [FALLO CRÍTICO VM en línea #%d (%s)]: %s", pc, lineaActual, ex.toString()));
            return false;
        }
    }

    private void exigirOperandosEnPila(String operacion, int cantidadRequerida) {
        if (pila.size() < cantidadRequerida) {
            throw new ExcepcionEjecucionVM(operacion + ": Se esperaban " + cantidadRequerida
                    + " operandos en la pila, pero solo hay " + pila.size() + ".");
        }
    }

    // Validación estricta de Producto: NO hace fallback silencioso a Leche (101)
    private Producto exigirProductoValido(String nombreOperacion, Object ref) {
        if (ref == null) {
            throw new ExcepcionEjecucionVM(nombreOperacion + ": Se esperaba un objeto PRODUCTO, pero se recibió null.");
        }
        if (ref instanceof Producto p) {
            return p;
        }
        if (ref instanceof Number num) {
            int idBuscado = num.intValue();
            Producto p = catalogoProductos.get(idBuscado);
            if (p == null) {
                throw new ExcepcionEjecucionVM(nombreOperacion + ": El producto con ID #" + idBuscado + " no existe en el inventario.");
            }
            return p;
        }
        if (ref instanceof String str) {
            for (Producto p : catalogoProductos.values()) {
                if (p.nombre.equalsIgnoreCase(str.trim())) {
                    return p;
                }
            }
            try {
                int idBuscado = Integer.parseInt(str.trim());
                Producto p = catalogoProductos.get(idBuscado);
                if (p != null) return p;
            } catch (NumberFormatException ignored) {
            }
        }
        throw new ExcepcionEjecucionVM(nombreOperacion + ": Tipo incompatible. Se esperaba un PRODUCTO válido pero se recibió: '" + ref + "'.");
    }

    private int aEnteroEstricto(String operacion, Object obj) {
        if (obj instanceof Number num) return num.intValue();
        if (obj instanceof Boolean b) return b ? 1 : 0;
        try {
            return (int) Double.parseDouble(String.valueOf(obj).trim());
        } catch (NumberFormatException e) {
            throw new ExcepcionEjecucionVM(operacion + ": Se esperaba un número entero, pero se recibió '" + obj + "'.");
        }
    }

    private double aNumeroEstricto(String operacion, Object obj) {
        if (obj instanceof Number num) return num.doubleValue();
        if (obj instanceof Boolean b) return b ? 1.0 : 0.0;
        try {
            return Double.parseDouble(String.valueOf(obj).trim());
        } catch (NumberFormatException e) {
            throw new ExcepcionEjecucionVM(operacion + ": Se esperaba un valor numérico, pero se recibió '" + obj + "'.");
        }
    }

    private int inferirAridadPorDefecto(String nombreFuncion) {
        return switch (nombreFuncion.toUpperCase()) {
            case "APPLY_DISCOUNT", "REGISTER_SALE", "SUMAR", "MULTIPLICAR", "HAS_NEXT", "GET_ITEM" -> 2;
            case "SHOW_ALERT", "GET_STOCK", "GET_PRODUCT_BY_ID", "CALCULATE_SALE_TOTAL", "SHOW_TOTAL", "MOSTRAR" -> 1;
            default -> 0;
        };
    }

    private Object parsearLiteral(String raw) {
        if (raw == null || raw.isEmpty() || "null".equalsIgnoreCase(raw)) return 0;
        if ("true".equalsIgnoreCase(raw)) return 1;
        if ("false".equalsIgnoreCase(raw)) return 0;
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException ignored) {
        }
        try {
            double d = Double.parseDouble(raw);
            if (d == Math.floor(d) && !Double.isInfinite(d)) return (int) d;
            return d;
        } catch (NumberFormatException ignored) {
        }
        if (raw.startsWith("[") && raw.endsWith("]")) {
            String contenido = raw.substring(1, raw.length() - 1).trim();
            if (contenido.isEmpty()) return new ArrayList<>();
            return new ArrayList<>(Arrays.asList(contenido.split("\\s*,\\s*")));
        }
        return raw;
    }

    @SuppressWarnings("unchecked")
    private List<Object> convertirALista(Object obj) {
        if (obj instanceof List<?>) {
            return (List<Object>) obj;
        }
        if (obj instanceof String str && !str.isBlank()) {
            String limpio = str.replace("[", "").replace("]", "").trim();
            if (limpio.isEmpty()) return new ArrayList<>();
            return new ArrayList<>(Arrays.asList(limpio.split("\\s*,\\s*")));
        }
        return new ArrayList<>();
    }

    private int aEntero(Object obj) {
        if (obj instanceof Number num) return num.intValue();
        if (obj instanceof Boolean b) return b ? 1 : 0;
        try {
            return (int) Double.parseDouble(String.valueOf(obj));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private boolean aBooleano(Object obj) {
        if (obj instanceof Boolean b) return b;
        if (obj instanceof Number num) return num.doubleValue() != 0.0;
        String s = String.valueOf(obj).trim();
        return "true".equalsIgnoreCase(s) || "1".equals(s);
    }

    private boolean sonIguales(Object a, Object b) {
        if (a == null && b == null) return true;
        if (a == null || b == null) return false;
        if (a instanceof Number numA && b instanceof Number numB) {
            return Double.compare(numA.doubleValue(), numB.doubleValue()) == 0;
        }
        return String.valueOf(a).equals(String.valueOf(b));
    }
}