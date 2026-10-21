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

    // Modelo de Producto para la Despensa
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
    // Pila de Scopes (Call Frames) para aislar las variables de las Subrutinas del programa principal
    private final Stack<Map<String, Object>> pilaScopes;
    private final Stack<Integer> pilaRetorno;
    // Memoria de datos inyectados por el Event Bus (ej. ProductoActual, lista_productos, lista_ids_descuento)
    private final Map<String, Object> memoriaEventos;

    // Base de datos en memoria de la Despensa
    private final Map<Integer, Producto> catalogoProductos;
    private Consumer<String> loggerCallback;

    public MaquinaVirtual() {
        this.pila = new Stack<>();
        this.pilaScopes = new Stack<>();
        this.pilaRetorno = new Stack<>();
        this.memoriaEventos = new HashMap<>();
        this.catalogoProductos = new LinkedHashMap<>();
        inicializarInventarioPorDefecto();
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

        // Contexto por defecto para pruebas directas
        inyectarDatoEvento("ProductoActual", catalogoProductos.get(101));
        inyectarDatoEvento("producto_leido", catalogoProductos.get(101));
        inyectarDatoEvento("lista_productos", new ArrayList<>(Arrays.asList(
                catalogoProductos.get(101),
                catalogoProductos.get(103)
        )));
        inyectarDatoEvento("lista_ids_descuento", new ArrayList<>(Arrays.asList(102, 104)));
    }

    public Map<Integer, Producto> getCatalogoProductos() {
        return catalogoProductos;
    }

    public void inyectarDatoEvento(String clave, Object valor) {
        memoriaEventos.put(clave, valor);
    }

    public Map<String, Object> getScopeActual() {
        return pilaScopes.isEmpty() ? memoriaEventos : pilaScopes.peek();
    }

    public void ejecutar(List<String> programa) {
        pila.clear();
        pilaScopes.clear();
        pilaRetorno.clear();
        // Scope raíz del programa principal
        pilaScopes.push(new HashMap<>());

        int pc = 0;
        while (pc < programa.size()) {
            String linea = programa.get(pc).trim();

            if (linea.isEmpty() || linea.startsWith("#") || linea.startsWith("//")) {
                pc++;
                continue;
            }

            String[] partes = linea.split("\\s+", 2);
            String instruccion = partes[0].toUpperCase();
            String operandoCrudo = partes.length > 1 ? partes[1].trim() : "";

            switch (instruccion) {
                case "PUSH", "PUSH_LITERAL" -> pila.push(parsearLiteral(operandoCrudo));

                case "POP" -> {
                    if (!pila.isEmpty()) pila.pop();
                }

                case "STORE", "STORE_VAR" -> {
                    Object valor = pila.isEmpty() ? 0 : pila.pop();
                    // Evitar que la inicialización en 0 pise un objeto ya inyectado por el Event Bus
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
                    } else {
                        valor = memoriaEventos.getOrDefault(operandoCrudo, 0);
                    }
                    pila.push(valor);
                }

                // --- LLAMADA Y RETORNO DE SUBRUTINAS CON AISLAMIENTO DE SCOPE ---
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
                    if (pilaRetorno.isEmpty()) return;
                    pc = pilaRetorno.pop();
                    log(" ↩️ [VM RET] Saliendo de Subrutina, retornando a línea " + pc);
                    continue;
                }

                case "ADD", "OP_ADD" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof String || b instanceof String) {
                        pila.push(String.valueOf(a) + String.valueOf(b));
                    } else if (a instanceof Double || b instanceof Double) {
                        pila.push(aNumero(a) + aNumero(b));
                    } else {
                        pila.push(aEntero(a) + aEntero(b));
                    }
                }

                case "SUB", "OP_SUB" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof Double || b instanceof Double) {
                        pila.push(aNumero(a) - aNumero(b));
                    } else {
                        pila.push(aEntero(a) - aEntero(b));
                    }
                }

                case "MUL", "OP_MUL" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof Double || b instanceof Double) {
                        pila.push(aNumero(a) * aNumero(b));
                    } else {
                        pila.push(aEntero(a) * aEntero(b));
                    }
                }

                case "DIV", "OP_DIV" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    double divisor = aNumero(b);
                    if (divisor == 0) throw new ArithmeticException("División por cero en línea " + pc);
                    if (a instanceof Double || b instanceof Double) {
                        pila.push(aNumero(a) / divisor);
                    } else {
                        pila.push(aEntero(a) / aEntero(b));
                    }
                }

                case "AND", "OP_AND" -> {
                    boolean b = aBooleano(pila.pop());
                    boolean a = aBooleano(pila.pop());
                    pila.push((a && b) ? 1 : 0);
                }

                case "OR", "OP_OR" -> {
                    boolean b = aBooleano(pila.pop());
                    boolean a = aBooleano(pila.pop());
                    pila.push((a || b) ? 1 : 0);
                }

                case "EQ", "OP_CMP_EQ" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    pila.push(sonIguales(a, b) ? 1 : 0);
                }

                case "GT", "OP_CMP_GT" -> {
                    double b = aNumero(pila.pop());
                    double a = aNumero(pila.pop());
                    pila.push(a > b ? 1 : 0);
                }

                case "LT", "OP_CMP_LT" -> {
                    double b = aNumero(pila.pop());
                    double a = aNumero(pila.pop());
                    pila.push(a < b ? 1 : 0);
                }

                case "PRINT" -> log(" 🖨️ [PRINT] " + pila.pop());

                case "JMP", "JUMP" -> {
                    pc = Integer.parseInt(operandoCrudo);
                    continue;
                }

                case "JMP_IF_TRUE" -> {
                    if (aBooleano(pila.pop())) {
                        pc = Integer.parseInt(operandoCrudo);
                        continue;
                    }
                }

                case "JMP_IF_FALSE", "JUMP_IF_FALSE" -> {
                    if (!aBooleano(pila.pop())) {
                        pc = Integer.parseInt(operandoCrudo);
                        continue;
                    }
                }

                case "CALL_HOST" -> {
                    String[] argsHost = operandoCrudo.split("\\s+");
                    String nombreFuncion = argsHost[0];
                    int aridad = (argsHost.length > 1) ? Integer.parseInt(argsHost[1]) : inferirAridadPorDefecto(nombreFuncion);

                    List<Object> parametros = new ArrayList<>();
                    for (int i = 0; i < aridad; i++) {
                        parametros.add(0, pila.isEmpty() ? null : pila.pop());
                    }

                    Object resultado = ejecutarHost(nombreFuncion, parametros);
                    pila.push(resultado);
                }

                case "HALT" -> {
                    log(" ✅ [VM HALT] Ejecución finalizada. Variables del Scope Principal: " + pilaScopes.peek());
                    return;
                }

                default -> throw new RuntimeException("Instrucción desconocida en línea " + pc + ": " + instruccion);
            }
            pc++;
        }
    }

    private Object ejecutarHost(String nombreFuncion, List<Object> parametros) {
        switch (nombreFuncion.toUpperCase()) {
            case "SUMAR" -> {
                return aEntero(parametros.get(0)) + aEntero(parametros.get(1));
            }
            case "MULTIPLICAR" -> {
                return aEntero(parametros.get(0)) * aEntero(parametros.get(1));
            }
            case "MOSTRAR" -> {
                log(" 💬 [MOSTRAR] " + parametros.get(0));
                return 0;
            }

            // --- CASO DE PRUEBA 3: ESCANEO Y CONTROL DE STOCK ---
            case "GET_STOCK" -> {
                Producto prod = resolverProducto(parametros.get(0));
                int stock = (prod != null) ? prod.stock : 0;
                log(" 📦 [GET_STOCK] Stock de '" + (prod != null ? prod.nombre : parametros.get(0)) + "' = " + stock);
                return stock;
            }

            case "SHOW_ALERT" -> {
                String msg = String.valueOf(parametros.get(0));
                log(" 🚨 [SHOW_ALERT] " + msg);
                return 0;
            }

            // --- CASO DE PRUEBA 2 Y 3: NAVIDAD Y APLICACIÓN DE DESCUENTOS ---
            case "GET_PRODUCT_BY_ID" -> {
                int idProd = aEntero(parametros.get(0));
                Producto prod = catalogoProductos.get(idProd);
                log(" 🔍 [GET_PRODUCT_BY_ID] Buscando ID #" + idProd + " -> " + (prod != null ? prod.nombre : "No encontrado"));
                return prod != null ? prod : idProd;
            }

            case "APPLY_DISCOUNT" -> {
                Producto prod = resolverProducto(parametros.get(0));
                double porcentaje = aNumero(parametros.get(1));
                if (prod != null) {
                    double precioAnterior = prod.precio;
                    prod.precio = Math.round((prod.precio * (1.0 - porcentaje / 100.0)) * 100.0) / 100.0;
                    log(String.format(" 🏷️ [APPLY_DISCOUNT] %.0f%% de descuento en '%s' ($%.2f -> $%.2f)",
                            porcentaje, prod.nombre, precioAnterior, prod.precio));
                } else {
                    log(" 🏷️ [APPLY_DISCOUNT] Descuento de " + porcentaje + "% aplicado a " + parametros.get(0));
                }
                return 0;
            }

            // --- CASO DE PRUEBA 1: FINALIZAR VENTA ---
            case "CALCULATE_SALE_TOTAL" -> {
                List<Object> lista = convertirALista(parametros.get(0));
                double total = 0.0;
                for (Object item : lista) {
                    Producto p = resolverProducto(item);
                    if (p != null) {
                        total += p.precio;
                    } else {
                        total += aNumero(item);
                    }
                }
                log(String.format(" 🧮 [CALCULATE_SALE_TOTAL] Total calculado para %d productos = $%.2f", lista.size(), total));
                return total;
            }

            case "REGISTER_SALE" -> {
                List<Object> lista = convertirALista(parametros.get(0));
                double total = aNumero(parametros.get(1));
                for (Object item : lista) {
                    Producto p = resolverProducto(item);
                    if (p != null && p.stock > 0) {
                        p.stock -= 1;
                    }
                }
                log(String.format(" 🧾 [REGISTER_SALE] Venta registrada con éxito (%d ítems) por $%.2f. Stock descontado.",
                        lista.size(), total));
                return 0;
            }

            case "SHOW_TOTAL" -> {
                double total = aNumero(parametros.get(0));
                log(String.format(" 💰 [SHOW_TOTAL] TOTAL A PAGAR EN CAJA: $%.2f", total));
                return 0;
            }

            // --- ITERACIÓN POLIMÓRFICA FOREACH ---
            case "HAS_NEXT" -> {
                int idx = aEntero(parametros.get(0));
                List<Object> lista = convertirALista(parametros.get(1));
                return (idx >= 0 && idx < lista.size()) ? 1 : 0;
            }

            case "GET_ITEM" -> {
                int idx = aEntero(parametros.get(0));
                List<Object> lista = convertirALista(parametros.get(1));
                return (idx >= 0 && idx < lista.size()) ? lista.get(idx) : null;
            }

            default -> {
                log(" ⚙️ [HOST CUSTOM '" + nombreFuncion + "'] Ejecutado con argumentos: " + parametros);
                return 0;
            }
        }
    }

    private Producto resolverProducto(Object ref) {
        if (ref instanceof Producto p) {
            return p;
        }
        if (ref instanceof Number num) {
            return catalogoProductos.get(num.intValue());
        }
        if (ref instanceof String str) {
            for (Producto p : catalogoProductos.values()) {
                if (p.nombre.equalsIgnoreCase(str) || str.contains(p.nombre)) {
                    return p;
                }
            }
            try {
                return catalogoProductos.get(Integer.parseInt(str.trim()));
            } catch (NumberFormatException ignored) {
            }
        }
        return catalogoProductos.get(101);
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

    private double aNumero(Object obj) {
        if (obj instanceof Number num) return num.doubleValue();
        if (obj instanceof Boolean b) return b ? 1.0 : 0.0;
        try {
            return Double.parseDouble(String.valueOf(obj));
        } catch (NumberFormatException e) {
            return 0.0;
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
        if (a instanceof Number && b instanceof Number) {
            return Double.compare(aNumero(a), aNumero(b)) == 0;
        }
        return String.valueOf(a).equals(String.valueOf(b));
    }
}
