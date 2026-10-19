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
import java.util.List;
import java.util.Map;
import java.util.Stack;

public class MaquinaVirtual {

    private final Stack<Object> pila;
    private final Map<String, Object> memoria;

    // Estado simulado de la Despensa (Entorno Host para pruebas de eventos y acciones)
    private final Map<String, Integer> stockDespensa;
    private final Map<String, Double> preciosDespensa;

    public MaquinaVirtual() {
        this.pila = new Stack<>();
        this.memoria = new HashMap<>();
        this.stockDespensa = new HashMap<>();
        this.preciosDespensa = new HashMap<>();
        inicializarEntornoDespensa();
    }

    private void inicializarEntornoDespensa() {
        // Productos de prueba en el inventario de la despensa
        stockDespensa.put("Producto Escaneado (Leche 1L)", 3);
        preciosDespensa.put("Producto Escaneado (Leche 1L)", 1200.0);

        stockDespensa.put("Arroz 1Kg", 15);
        preciosDespensa.put("Arroz 1Kg", 1500.0);

        // Variable inyectada por defecto cuando se dispara ON_PRODUCT_SCANNED
        memoria.put("ProductoActual", "Producto Escaneado (Leche 1L)");
    }

    public void ejecutar(List<String> programa) {
        int pc = 0;
        while (pc < programa.size()) {
            String linea = programa.get(pc).trim();

            // Ignorar líneas vacías o comentarios
            if (linea.isEmpty() || linea.startsWith("#") || linea.startsWith("//")) {
                pc++;
                continue;
            }

            // Separar únicamente el OpCode (partes[0]) del resto del operando (partes[1])
            String[] partes = linea.split("\\s+", 2);
            String instruccion = partes[0].toUpperCase();
            String operandoCrudo = partes.length > 1 ? partes[1].trim() : "";

            switch (instruccion) {
                case "PUSH", "PUSH_LITERAL" -> {
                    pila.push(parsearLiteral(operandoCrudo));
                }

                case "POP" -> {
                    if (!pila.isEmpty()) {
                        pila.pop();
                    }
                }

                case "STORE", "STORE_VAR" -> {
                    Object valor = pila.isEmpty() ? 0 : pila.pop();
                    // Si la variable es ProductoActual y el compilador la inicializa en 0 por defecto,
                    // preservamos el producto escaneado del entorno si el valor es 0
                    if ("ProductoActual".equals(operandoCrudo) && Integer.valueOf(0).equals(valor)
                            && memoria.containsKey("ProductoActual")) {
                        // Mantener el producto del evento ON_PRODUCT_SCANNED
                    } else {
                        memoria.put(operandoCrudo, valor);
                    }
                }

                case "LOAD", "LOAD_VAR" -> {
                    Object valor = memoria.getOrDefault(operandoCrudo, 0);
                    pila.push(valor);
                }

                case "ADD", "OP_ADD" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof String || b instanceof String) {
                        pila.push(String.valueOf(a) + String.valueOf(b));
                    } else if (a instanceof Double || b instanceof Double) {
                        pila.push( aNumero(a) + aNumero(b) );
                    } else {
                        pila.push( aEntero(a) + aEntero(b) );
                    }
                }

                case "SUB", "OP_SUB" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof Double || b instanceof Double) {
                        pila.push( aNumero(a) - aNumero(b) );
                    } else {
                        pila.push( aEntero(a) - aEntero(b) );
                    }
                }

                case "MUL", "OP_MUL" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    if (a instanceof Double || b instanceof Double) {
                        pila.push( aNumero(a) * aNumero(b) );
                    } else {
                        pila.push( aEntero(a) * aEntero(b) );
                    }
                }

                case "DIV", "OP_DIV" -> {
                    Object b = pila.pop();
                    Object a = pila.pop();
                    double divisor = aNumero(b);
                    if (divisor == 0) {
                        throw new ArithmeticException("Error en VM: División por cero en la línea " + pc);
                    }
                    if (a instanceof Double || b instanceof Double) {
                        pila.push( aNumero(a) / divisor );
                    } else {
                        pila.push( aEntero(a) / aEntero(b) );
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

                case "PRINT" -> {
                    System.out.println("[PRINT] " + pila.pop());
                }

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
                    System.out.println("\n[VM] Ejecución finalizada (HALT). Estado final de Memoria: " + memoria);
                    return;
                }

                default -> throw new RuntimeException("Instrucción desconocida en línea " + pc + ": " + instruccion);
            }
            pc++;
        }
    }

    private Object ejecutarHost(String nombreFuncion, List<Object> parametros) {
        switch (nombreFuncion.toUpperCase()) {
            // --- FUNCIONES LEGACY DE PRUEBA ---
            case "SUMAR" -> {
                return aEntero(parametros.get(0)) + aEntero(parametros.get(1));
            }
            case "MULTIPLICAR" -> {
                return aEntero(parametros.get(0)) * aEntero(parametros.get(1));
            }
            case "MOSTRAR" -> {
                System.out.println("[HOST MOSTRAR] " + parametros.get(0));
                return 0;
            }

            // --- FUNCIONES NATIVAS DEL DOMINIO DE LA DESPENSA ---
            case "GET_STOCK" -> {
                String producto = String.valueOf(parametros.get(0));
                int stock = stockDespensa.getOrDefault(producto, 3);
                System.out.println(" 📦 [HOST GET_STOCK] Consultando stock de '" + producto + "' -> " + stock + " unidades.");
                return stock;
            }

            case "SHOW_ALERT" -> {
                String mensaje = String.valueOf(parametros.get(0));
                System.out.println(" 🚨 [ALERTA DEL SISTEMA]: " + mensaje);
                return 0;
            }

            case "APPLY_DISCOUNT" -> {
                String producto = String.valueOf(parametros.get(0));
                double porcentaje = aNumero(parametros.get(1));
                double precioBase = preciosDespensa.getOrDefault(producto, 1000.0);
                double precioFinal = precioBase * (1.0 - (porcentaje / 100.0));
                preciosDespensa.put(producto, precioFinal);
                System.out.println(String.format(
                        " 🏷️ [HOST APPLY_DISCOUNT] Descuento del %.1f%% aplicado a '%s' ($%.2f -> $%.2f)",
                        porcentaje, producto, precioBase, precioFinal));
                return 0;
            }

            // --- SOPORTE PARA BUCLE FOREACH ---
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

            // --- BLOQUES DE ACCIÓN PERSONALIZADOS CREADOS POR EL USUARIO ---
            default -> {
                System.out.println(" ⚙️ [HOST CUSTOM '" + nombreFuncion + "'] Ejecutado con parámetros: " + parametros);
                return 0;
            }
        }
    }

    private int inferirAridadPorDefecto(String nombreFuncion) {
        return switch (nombreFuncion.toUpperCase()) {
            case "APPLY_DISCOUNT", "SUMAR", "MULTIPLICAR", "HAS_NEXT", "GET_ITEM" -> 2;
            case "SHOW_ALERT", "GET_STOCK", "MOSTRAR" -> 1;
            default -> 0;
        };
    }

    private Object parsearLiteral(String raw) {
        if (raw == null || raw.isEmpty() || "null".equalsIgnoreCase(raw)) {
            return 0;
        }
        if ("true".equalsIgnoreCase(raw)) {
            return 1;
        }
        if ("false".equalsIgnoreCase(raw)) {
            return 0;
        }
        // Intentar como entero
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException ignored) {
        }
        // Intentar como decimal (ej. 5.0)
        try {
            double d = Double.parseDouble(raw);
            if (d == Math.floor(d) && !Double.isInfinite(d)) {
                return (int) d;
            }
            return d;
        } catch (NumberFormatException ignored) {
        }
        // Si es una lista entre corchetes o separada por comas (para ForEach)
        if (raw.startsWith("[") && raw.endsWith("]")) {
            String contenido = raw.substring(1, raw.length() - 1).trim();
            if (contenido.isEmpty()) return new ArrayList<>();
            return new ArrayList<>(Arrays.asList(contenido.split("\\s*,\\s*")));
        }
        // Por defecto, devolver el texto íntegro con sus espacios
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
        if (obj instanceof Number num) {
            return num.intValue();
        }
        if (obj instanceof Boolean b) {
            return b ? 1 : 0;
        }
        try {
            return (int) Double.parseDouble(String.valueOf(obj));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private double aNumero(Object obj) {
        if (obj instanceof Number num) {
            return num.doubleValue();
        }
        if (obj instanceof Boolean b) {
            return b ? 1.0 : 0.0;
        }
        try {
            return Double.parseDouble(String.valueOf(obj));
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    private boolean aBooleano(Object obj) {
        if (obj instanceof Boolean b) {
            return b;
        }
        if (obj instanceof Number num) {
            return num.doubleValue() != 0.0;
        }
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
