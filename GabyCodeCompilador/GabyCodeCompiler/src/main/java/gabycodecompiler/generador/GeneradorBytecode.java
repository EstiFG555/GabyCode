/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */

/**
 *
 * @author facu
 */
package gabycodecompiler.generador;

import gabycodecompiler.modelo.EntradaDato;
import gabycodecompiler.modelo.Grafo;
import gabycodecompiler.modelo.Nodo;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class GeneradorBytecode {

    // Sobrecarga compatible con versiones previas
    public static List<Instruccion> generar(List<Nodo> nodos) {
        Grafo g = new Grafo();
        g.setNodos(nodos);
        return generar(g);
    }

    public static List<Instruccion> generar(Grafo grafo) {
        List<Instruccion> instrucciones = new ArrayList<>();
        if (grafo == null || grafo.getNodos() == null || grafo.getNodos().isEmpty()) {
            return instrucciones;
        }

        // 1. Mapa rápido de nodos por ID y detección de nodos cuyos datos son referenciados
        Map<Integer, Nodo> mapaNodos = new HashMap<>();
        Set<Integer> nodosReferenciados = new HashSet<>();

        for (Nodo n : grafo.getNodos()) {
            mapaNodos.put(n.getId(), n);
            if (n.getDatosEntrada() != null) {
                for (EntradaDato ed : n.getDatosEntrada().values()) {
                    if (ed != null && "REFERENCIA_NODO".equalsIgnoreCase(ed.getFuente()) && ed.getIdOrigen() != null) {
                        nodosReferenciados.add(ed.getIdOrigen());
                    }
                }
            }
        }

        // 2. Cabecera: Inicializar todas las variables_locales declaradas por el usuario en la pila/memoria
        if (grafo.getVariablesLocales() != null) {
            for (Map<String, Object> varLocal : grafo.getVariablesLocales()) {
                String nombre = String.valueOf(varLocal.get("nombre"));
                Object valorInicial = varLocal.get("valor_inicial");
                if (valorInicial == null) {
                    valorInicial = 0;
                }
                instrucciones.add(new Instruccion(CodigoOperacion.PUSH, formatearLiteral(valorInicial)));
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, nombre));
            }
        }

        // 3. Buscar el Evento Raíz para comenzar la compilación del flujo temporal
        Nodo nodoEvento = null;
        for (Nodo n : grafo.getNodos()) {
            if ("EVENTO".equalsIgnoreCase(n.getTipo())) {
                nodoEvento = n;
                break;
            }
        }
        if (nodoEvento == null) {
            nodoEvento = grafo.getNodos().get(0);
        }

        // 4. Compilar recursivamente el flujo de ejecución
        compilarSecuencia(nodoEvento.getId(), mapaNodos, nodosReferenciados, instrucciones);

        // 5. Instrucción de cierre del programa
        instrucciones.add(new Instruccion(CodigoOperacion.HALT));

        return instrucciones;
    }

    private static void compilarSecuencia(
            int idActual,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones) {

        while (idActual > 0) {
            Nodo nodo = mapaNodos.get(idActual);
            if (nodo == null) break;

            String tipo = nodo.getTipo() != null ? nodo.getTipo().toUpperCase() : "";
            String operacion = nodo.getOperacion() != null ? nodo.getOperacion().toUpperCase() : "";

            switch (tipo) {
                case "EVENTO":
                    // Si otros bloques leen la salida del evento (ej. ON_PRODUCT_SCANNED),
                    // su valor provendrá de la variable de entorno "ProductoActual"
                    idActual = obtenerSalida(nodo, 0);
                    break;

                case "CONTROL":
                    compilarNodoControl(nodo, operacion, mapaNodos, nodosReferenciados, instrucciones);
                    // En los nodos CONTROL, el índice 2 de salidas_ejecucion es el cable principal post-bloque
                    idActual = obtenerSalida(nodo, 2);
                    break;

                case "ACCION":
                case "ACCIÓN":
                default:
                    compilarNodoAccion(nodo, operacion, mapaNodos, nodosReferenciados, instrucciones);
                    idActual = obtenerSalida(nodo, 0);
                    break;
            }
        }
    }

    private static void compilarNodoControl(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones) {

        int idRamaVerdadera = obtenerSalida(nodo, 0);
        int idRamaFalsa = obtenerSalida(nodo, 1);

        if ("IF_ELSE".equals(operacion)) {
            // 1. Evaluar la condición booleana
            EntradaDato cond = obtenerEntrada(nodo, "condicion");
            evaluarEntradaDato(cond, mapaNodos, instrucciones);

            // 2. Emitir salto condicional si es falso (Backpatching)
            Instruccion jmpIfFalse = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpIfFalse);

            // 3. Compilar la rama verdadera (SI)
            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones);
            }

            if (idRamaFalsa > 0) {
                // Emitir salto incondicional al final del IF para esquivar el ELSE
                Instruccion jmpFinIf = new Instruccion(CodigoOperacion.JMP, 0);
                instrucciones.add(jmpFinIf);

                // El ELSE comienza exactamente en el índice actual
                jmpIfFalse.setOperando(instrucciones.size());

                // 4. Compilar la rama falsa (SI NO)
                compilarSecuencia(idRamaFalsa, mapaNodos, nodosReferenciados, instrucciones);

                // El fin del IF_ELSE es el índice actual
                jmpFinIf.setOperando(instrucciones.size());
            } else {
                // Si no hay rama ELSE, el salto falso apunta directamente aquí
                jmpIfFalse.setOperando(instrucciones.size());
            }

        } else if ("WHILE".equals(operacion)) {
            // 1. Guardar la línea donde inicia la re-evaluación de la condición
            int indiceInicioBucle = instrucciones.size();

            // 2. Evaluar la condición en cada iteración
            EntradaDato cond = obtenerEntrada(nodo, "condicion");
            evaluarEntradaDato(cond, mapaNodos, instrucciones);

            // 3. Si es falso, salir del bucle
            Instruccion jmpSalida = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpSalida);

            // 4. Compilar el cuerpo del bucle
            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones);
            }

            // 5. Volver al inicio del bucle
            instrucciones.add(new Instruccion(CodigoOperacion.JMP, indiceInicioBucle));

            // 6. Rellenar el destino de salida del bucle
            jmpSalida.setOperando(instrucciones.size());

        } else if ("FOREACH".equals(operacion)) {
            // Implementación linealizada de ForEach sobre colección
            EntradaDato varIter = obtenerEntrada(nodo, "variable_iteradora");
            String nombreVarIter = (varIter != null && varIter.getNombre() != null) ? varIter.getNombre() : "__iter_item";
            String varIndice = "__idx_" + nodo.getId();

            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 0));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, varIndice));

            int indiceInicioFor = instrucciones.size();
            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            EntradaDato coleccion = obtenerEntrada(nodo, "coleccion");
            evaluarEntradaDato(coleccion, mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "HAS_NEXT 2"));

            Instruccion jmpSalida = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpSalida);

            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            evaluarEntradaDato(coleccion, mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "GET_ITEM 2"));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, nombreVarIter));
            if (nodosReferenciados.contains(nodo.getId())) {
                instrucciones.add(new Instruccion(CodigoOperacion.LOAD, nombreVarIter));
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, "__salida_nodo_" + nodo.getId()));
            }

            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones);
            }

            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 1));
            instrucciones.add(new Instruccion(CodigoOperacion.ADD));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, varIndice));
            instrucciones.add(new Instruccion(CodigoOperacion.JMP, indiceInicioFor));

            jmpSalida.setOperando(instrucciones.size());
        }
    }

    private static void compilarNodoAccion(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones) {

        // Caso especial nativo: Asignación de variable (SET_VAR)
        if ("SET_VAR".equals(operacion)) {
            EntradaDato entradaValor = obtenerEntrada(nodo, "valor");
            EntradaDato entradaDestino = obtenerEntrada(nodo, "variable_destino");
            if (entradaDestino != null && entradaDestino.getNombre() != null) {
                evaluarEntradaDato(entradaValor, mapaNodos, instrucciones);
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, entradaDestino.getNombre()));
            }
            return;
        }

        // Apilar los argumentos de entrada en orden determinista
        int aridad = apilarArgumentosAccion(nodo, operacion, mapaNodos, instrucciones);

        // Emitir llamada al Host incluyendo la aridad (ej: CALL_HOST APPLY_DISCOUNT 2)
        instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, operacion + " " + aridad));

        // Si otro nodo del grafo usa la salida de esta acción (ej. GET_STOCK),
        // guardamos el retorno en una variable sintética de memoria.
        // Si nadie la usa, limpiamos el valor residual de la pila con POP.
        if (nodosReferenciados.contains(nodo.getId())) {
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, "__salida_nodo_" + nodo.getId()));
        } else {
            instrucciones.add(new Instruccion(CodigoOperacion.POP));
        }
    }

    private static int apilarArgumentosAccion(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        if (nodo.getDatosEntrada() == null || nodo.getDatosEntrada().isEmpty()) {
            return 0;
        }

        // Garantizar el orden exacto de parámetros en las acciones conocidas
        if ("APPLY_DISCOUNT".equals(operacion)) {
            evaluarEntradaDato(obtenerEntrada(nodo, "producto"), mapaNodos, instrucciones);
            evaluarEntradaDato(obtenerEntrada(nodo, "porcentaje"), mapaNodos, instrucciones);
            return 2;
        } else if ("SHOW_ALERT".equals(operacion)) {
            evaluarEntradaDato(obtenerEntrada(nodo, "mensaje"), mapaNodos, instrucciones);
            return 1;
        } else if ("GET_STOCK".equals(operacion)) {
            evaluarEntradaDato(obtenerEntrada(nodo, "producto"), mapaNodos, instrucciones);
            return 1;
        }

        // Para bloques de Acción personalizados creados por el usuario
        int count = 0;
        for (Map.Entry<String, EntradaDato> entry : nodo.getDatosEntrada().entrySet()) {
            if (entry.getValue() != null) {
                evaluarEntradaDato(entry.getValue(), mapaNodos, instrucciones);
                count++;
            }
        }
        return count;
    }

    private static void compilarNodoExpresion(
            Nodo nodoExpr,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        String op = nodoExpr.getOperacion() != null ? nodoExpr.getOperacion().toUpperCase() : "";

        // Caso especial si GET_STOCK fue definido como EXPRESION en algún JSON de prueba antiguo
        if ("GET_STOCK".equals(op)) {
            evaluarEntradaDato(obtenerEntrada(nodoExpr, "producto"), mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "GET_STOCK 1"));
            return;
        }

        // Orden estricto: Primero valor_a, luego valor_b (para que en la pila quede [a, b])
        evaluarEntradaDato(obtenerEntrada(nodoExpr, "valor_a"), mapaNodos, instrucciones);
        evaluarEntradaDato(obtenerEntrada(nodoExpr, "valor_b"), mapaNodos, instrucciones);

        switch (op) {
            case "LESS_THAN":
            case "OP_CMP_LT":
                instrucciones.add(new Instruccion(CodigoOperacion.LT));
                break;
            case "GREATER_THAN":
            case "OP_CMP_GT":
                instrucciones.add(new Instruccion(CodigoOperacion.GT));
                break;
            case "EQUAL":
            case "OP_CMP_EQ":
                instrucciones.add(new Instruccion(CodigoOperacion.EQ));
                break;
            case "ADD":
            case "OP_ADD":
                instrucciones.add(new Instruccion(CodigoOperacion.ADD));
                break;
            case "SUB":
            case "OP_SUB":
                instrucciones.add(new Instruccion(CodigoOperacion.SUB));
                break;
            case "MUL":
            case "OP_MUL":
                instrucciones.add(new Instruccion(CodigoOperacion.MUL));
                break;
            case "DIV":
            case "OP_DIV":
                instrucciones.add(new Instruccion(CodigoOperacion.DIV));
                break;
            case "AND":
            case "OP_AND":
                instrucciones.add(new Instruccion(CodigoOperacion.AND));
                break;
            case "OR":
            case "OP_OR":
                instrucciones.add(new Instruccion(CodigoOperacion.OR));
                break;
            default:
                throw new IllegalArgumentException("Operación de expresión desconocida: " + op);
        }
    }

    private static void evaluarEntradaDato(
            EntradaDato entrada,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        if (entrada == null || entrada.getFuente() == null) {
            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 0));
            return;
        }

        String fuente = entrada.getFuente().toUpperCase();
        switch (fuente) {
            case "LITERAL":
                instrucciones.add(new Instruccion(CodigoOperacion.PUSH, formatearLiteral(entrada.getValor())));
                break;

            case "VARIABLE":
                instrucciones.add(new Instruccion(CodigoOperacion.LOAD, entrada.getNombre()));
                break;

            case "REFERENCIA_NODO":
                if (entrada.getIdOrigen() != null) {
                    Nodo nodoOrigen = mapaNodos.get(entrada.getIdOrigen());
                    if (nodoOrigen != null) {
                        if ("EXPRESION".equalsIgnoreCase(nodoOrigen.getTipo())) {
                            // Las expresiones se evalúan in-place de forma recursiva
                            compilarNodoExpresion(nodoOrigen, mapaNodos, instrucciones);
                        } else if ("EVENTO".equalsIgnoreCase(nodoOrigen.getTipo())) {
                            // La salida del evento raíz lee la variable inyectada por el entorno
                            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, "ProductoActual"));
                        } else {
                            // La salida de una Acción o Control previo se lee de su variable sintética
                            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, "__salida_nodo_" + nodoOrigen.getId()));
                        }
                    }
                }
                break;
        }
    }

    private static EntradaDato obtenerEntrada(Nodo nodo, String clave) {
        if (nodo.getDatosEntrada() == null) return null;
        return nodo.getDatosEntrada().get(clave);
    }

    private static int obtenerSalida(Nodo nodo, int indice) {
        if (nodo.getSalidasEjecucion() == null || indice >= nodo.getSalidasEjecucion().size()) {
            return 0;
        }
        Integer id = nodo.getSalidasEjecucion().get(indice);
        return id != null ? id : 0;
    }

    // Evita que Gson convierta enteros como 5 en "5.0" rompiendo la VM
    private static Object formatearLiteral(Object valor) {
        if (valor instanceof Double) {
            Double d = (Double) valor;
            if (d == Math.floor(d) && !Double.isInfinite(d)) {
                return d.intValue();
            }
        }
        return valor;
    }
}
